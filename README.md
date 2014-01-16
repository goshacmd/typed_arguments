# Typed arguments

Ever wanted to ensure that method arguments are of specific type in Ruby?

Well, now you can:

```ruby
class Person
  +[String, Integer]
  def initialize(name, age)
    @name, @age = name, age
  end

  +[Time]
  def self.valid_dob?(date)
    true
  end
end

p1 = Person.new "Noah", 20 # all good

p2 = Person.new :Name, 6.66
# ArgumentError: expected argument 'name' to be of type String, argument 'age' to be of type Integer

Person.valid_dob?(Time.now) # all good

Person.valid_dob?(10)
# ArgumentError: expected argument 'date' to be of type Time
```

## Installation

Add this line to your application's Gemfile:

    gem 'typed_arguments'

Or install it yourself as:

    $ gem install typed_arguments

## License

[MIT](LICENSE).
