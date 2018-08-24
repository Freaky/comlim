require "comlim/version"

class Comlim
  module ExitReason
    Normal           = Class.new
    OutputExceeded   = Class.new
    WalltimeExceeded = Class.new
    Killed           = Class.new
  end

  Result = Struct.new(:pid, :status, :exitstatus, :exitreason, :stdout, :stderr, :walltime)

  READ_BLOCKSIZE=65535

  def initialize(opts = {})
    @opts = opts
  end

  class << self
    %i(command arg args memory cputime walltime output stdout stderr env).each do |m|
      define_method(m) do |*arg|
        new.__send__(m, *arg)
      end
    end
  end

  def clone(opts = {})
    self.class.new(@opts.merge(opts))
  end

  def command(cmd)
    clone(command: cmd.to_s)
  end

  def arg(arg)
    clone(args: Array(@opts[:args]) + Array(arg))
  end

  def args(*args)
    clone(args: Array(@opts[:args]) + Array(args))
  end

  def arg!(arg)
    clone(args: Array(arg))
  end

  def args!(args)
    clone(args: Array(args))
  end

  def memory(bytes)
    clone(memory: Integer(bytes))
  end

  def cputime(time)
    clone(cputime: Float(time))
  end

  def walltime(time)
    clone(walltime: Float(time))
  end

  def output(bytes)
    clone(output: Integer(bytes))
  end

  def stdout(bytes)
    clone(stdout: Integer(bytes))
  end

  def stderr(bytes)
    clone(stderr: Integer(bytes))
  end

  def env(e)
    clone(env: e)
  end

  def execute
    stdout = +''
    stderr = +''

    outr, outw = IO.pipe
    errr, errw = IO.pipe

    iomap = {outr => stdout, errr => stderr}

    start_time = monotime
    deadline = start_time + @opts.fetch(:walltime, 3600)

    args = {
      rlimit_cpu: @opts[:cputime],
      rlimit_as: @opts[:memory],
      in: '/dev/null',
      out: outw,
      err: errw
    }.delete_if { |k,v| v.nil? }
    pid = Process.spawn(*[@opts.fetch(:command), *@opts.fetch(:args, [])], args)

    outw.close
    errw.close

    exitreason = handle_io(iomap, deadline: deadline, limit: @opts.fetch(:output, Float::INFINITY))

    _, status = timed_waitpid2(pid, deadline: deadline)

    unless status
      terminate(pid)
      _, status = Process.waitpid2(pid)
    end

    if exitreason == ExitReason::Normal && status.termsig == 9
      exitreason = ExitReason::Killed
    end

    Result.new(pid, status, status.exitstatus, exitreason, stdout, stderr, monotime - start_time).freeze
  end

  private
  def monotime
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def handle_io(iomap, deadline:, limit:)
    fds, strings = iomap.keys, iomap.values
    readsize = limit.clamp(0, READ_BLOCKSIZE)

    exitreason = ExitReason::Normal

    begin
      timeout = deadline - monotime
      if timeout < 0 # keep this out of the loop conditional to avoid racing
        exitreason = ExitReason::WalltimeExceeded
        break
      end

      begin
        ready = IO.select(fds, nil, fds, timeout)
      rescue Errno::EINTR
        retry # interrupted by signal
      end

      if ready
        readable, _, errored = ready

        (readable | errored).each do |io|
          begin
            iomap[io].concat io.read_nonblock(readsize)
          rescue IO::WaitReadable
          rescue EOFError, SystemCallError
            fds.delete io
          end
        end

        fds -= errored

        if strings.sum(&:bytesize) >= limit
          exitreason = ExitReason::OutputExceeded
          break
        end
      end
    end while fds.any?

    exitreason
  ensure
    iomap.each_key { |fd| fd.close rescue nil }
  end

  def timed_waitpid2(pid, deadline:)
    until status = Process.waitpid2(pid, Process::WNOHANG)
      break if monotime >= deadline
      sleep 0.01
    end

    return status
  end

  def terminate(pid)
    Process.kill(:KILL, pid)
  rescue Errno::ESRCH
  end
end
