# frozen_string_literal: true

require "helper"

class TestRemoteServerControlCommands < Minitest::Test
  include Helper::Client

  def test_info
    keys = [
      "redis_version",
      "uptime_in_seconds",
      "uptime_in_days",
      "connected_clients",
      "used_memory",
      "total_connections_received",
      "total_commands_processed"
    ]

    info = r.info

    keys.each do |k|
      msg = "expected #info to include #{k}"
      assert info.key?(k), msg
    end
  end

  def test_info_commandstats
    r.config(:resetstat)
    r.get("foo")
    r.get("bar")

    result = r.info(:commandstats)
    assert_equal '2', result['get']['calls']
  end

  def test_monitor_redis
    log = []

    thread = Thread.new do
      Redis.new(OPTIONS).monitor do |line|
        log << line
        break if line.include?("set")
      end
    end

    Thread.pass while log.empty? # Faster than sleep

    r.set "foo", "s1"

    thread.join

    assert log[-1] =~ /\b15\b.* "set" "foo" "s1"/
  end

  def test_monitor_returns_value_for_break
    result = r.monitor do |line|
      break line
    end

    assert_equal "OK", result
  end

  def test_echo
    assert_equal "foo bar baz\n", r.echo("foo bar baz\n")
  end

  def test_debug
    r.set "foo", "s1"

    assert r.debug(:object, "foo").is_a?(String)
  end

  def test_object
    r.lpush "list", "value"

    assert_equal 1, r.object(:refcount, "list")
    encoding = r.object(:encoding, "list")
    assert encoding == "ziplist" || encoding == "quicklist", "Wrong encoding for list"
    assert r.object(:idletime, "list").is_a?(Integer)
  end

  def test_sync
    redis_mock(sync: -> { "+OK" }) do |redis|
      assert_equal "OK", redis.sync
    end
  end

  def test_slowlog
    r.slowlog(:reset)
    result = r.slowlog(:len)
    assert_equal 0, result
  end

  def test_client
    assert_equal r.instance_variable_get(:@client), r._client
  end

  def test_client_list
    keys = [
      "addr",
      "fd",
      "name",
      "age",
      "idle",
      "flags",
      "db",
      "sub",
      "psub",
      "multi",
      "qbuf",
      "qbuf-free",
      "obl",
      "oll",
      "omem",
      "events",
      "cmd"
    ]

    clients = r.client(:list)
    clients.each do |client|
      keys.each do |k|
        msg = "expected #client(:list) to include #{k}"
        assert client.key?(k), msg
      end
    end
  end

  def test_client_kill
    r.client(:setname, 'redis-rb')
    clients = r.client(:list)
    i = clients.index { |client| client['name'] == 'redis-rb' }
    assert_equal "OK", r.client(:kill, clients[i]["addr"])

    clients = r.client(:list)
    i = clients.index { |client| client['name'] == 'redis-rb' }
    assert_nil i
  end

  def test_client_getname_and_setname
    assert_nil r.client(:getname)

    r.client(:setname, 'redis-rb')
    name = r.client(:getname)
    assert_equal 'redis-rb', name
  end
end
