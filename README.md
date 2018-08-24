# Comlim

A subprocess command builder/runner with a focus on enforcing limits to
runtime, memory use, CPU use, and command output.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'comlim'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install comlim

(Then get upset when you realise I haven't pushed this to the masses yet).

## Usage

Limit stdout and stderr to a total of 1KiB.

```ruby
QuietRunner = Comlim.output(1024)
```

Limit it to 32MiB of memory.

```ruby
MemLimitedRunner = QuietRunner.memory(1024 * 1024 * 32)
```

2 seconds of CPU should be plenty:

```ruby
CpuMemLimitedRunner = MemLimitedRunner.cputime(2)
```

4 seconds of runtime, followed by summary execution:

```ruby
RestrictedRunner = CpuMemLimitedRunner.walltime(4)
```

Use it to run inline Ruby:

```ruby
RubyRunner = RestrictedRunner.command('ruby').arg('-e')
```

And finally use it to run some potentially runaway process:

```ruby
result = RubyRunner.arg('loop { puts "SMASH THE STATE!" }')
pp result
# => #<struct Comlim::Result
# => pid=95544,
# => status=#<Process::Status: pid 95544 exit 1>,
# => exitstatus=1,
# => exitreason=Comlim::ExitReason::OutputExceeded,
# => stdout=
# =>  "SMASH THE STATE!\n" +
# =>  "SMASH THE STATE!\n" +
# =>  ...
# =>  [SUBVERSIVE MESSAGE REDACTED]
# => stderr="",
# => walltime=0.1225816321093589>
```

Bwahahaha.  Ahem.

## Status

Eh, it probably mostly works on my machine.  I guess?

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Freaky/comlim.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
