# Replidog

Multiple mlaster/slave helper for ActiveRecord

Based on https://github.com/r7kamura/replicat

## Features

* Multiple master/slave
* Auto switching between master/slave
* Supports connection management and query cache
* Supports Rails 3.2, 4.0, 4,1, 4.2, 5.0, 5.1

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'replidog'
```

And then execute:

```sh
$ bundle
```

Or install it yourself as:

```sh
$ gem install replidog
```

## Usage

### configuration

```ruby
# config/database.yml
production:
  adapter: mysql2
  encoding: utf8
  host: 192.168.24.1
  port: 3306
  replications:
    slave1:
      adapter: mysql2
      encoding: utf8
      host: 192.168.24.2
      port: 3306
    slave2:
      adapter: mysql2
      encoding: utf8
      host: 192.168.24.3
      port: 3306
    slave3:
      adapter: mysql2
      encoding: utf8
      host: 192.168.24.4
      port: 3306
```

### replication

Now SELECT queries of User model will be sent to slave connections.

```ruby
# INSERT query is sent to master.
User.create(name: "replicat")

# SELECT query is sent to slave.
User.first
```

### using

`using` can help you specify particular connection.
When you want to send queries to master,
you can use `using(:master)` to do that (:master is reserved name for `using` method).
When you want to send queries to a particular slave,
you can use the slave's name on database.yml like `using(:slave1)`.

```ruby
# SELECT query is sent to master.
User.using(:master).first

# INSERT query is sent to slave1.
User.using(:slave1).create(name: "replicat")

# :slave1 is used for User connection in the passed block.
User.using(:slave1) { blog.user }
```

### round-robin

slave connections are balanced by round-robin way.

```ruby
User.first # sent to slave1
User.first # sent to slave2
User.first # sent to slave3
User.first # sent to slave1
User.first # sent to slave2
User.first # sent to slave3
User.first # sent to slave1
User.first # sent to slave2
User.first # sent to slave3
```

### multi master-slave set

Pass the master's connection name to `replicate` method.

```ruby
# app/models/recipe.rb
class Recipe < RecipeTable
  establish_connection :production_recipe
end

# config/database.yml
production_base:
  adapter: mysql2
  encoding: utf8
  port: 3306
production:
  <<: *production_base
  host: 192.168.24.1
  replications:
    slave1:
      <<: *slave
      host: 192.168.24.2
    slave2:
      <<: *slave
      host: 192.168.24.3
    slave3:
      <<: *slave
      host: 192.168.24.4

production_recipe:
  <<: *production_base
  host: 192.168.24.5
  replications:
    slave1:
      <<: *slave
      host: 192.168.24.6
    slave2:
      <<: *slave
      host: 192.168.24.7
    slave3:
      <<: *slave
      host: 192.168.24.8
```

If you want to connecto to `production_recipe` in multiple models, Create Abstract class and extend it.

```ruby
# app/models/recipe_table.rb
class RecipeTable < ActiveRecord::Base
  self.abstract_class = true
  establish_connection :production_recipe
end

# app/models/recipe.rb
class Recipe < RecipeTable
end
```

### connection management / query cache

To handle all master/slave connections togegher, the methods related with connection management and query cache are overridden.
So you don't need to update middlewares and configurations for app servers.

List of overridden methods
* ActiveRecord::Base.clear_active_connections
* ActiveRecord::Base.clear_reloadable_connections
* ActiveRecord::Base.clear_all_connections
* ActiveRecord::Base.connection.enable_query_cache!
* ActiveRecord::Base.connection.disable_query_cache!
* ActiveRecord::Base.connection.clear_query_cache!


## Contributing

```
# setup gems
bundle install
appraisal install

# setup databases
rake db:prepare

# run tests for current gemfile
rake

# run tests for all appraisals
appraisal rake
```
