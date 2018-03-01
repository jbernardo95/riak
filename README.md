# riak

This is a fork of [riak](https://github.com/basho/riak) altered to have support for transactions.

## Dependencies 

- Erlang R16B02
- GNU-style build system
- [This](https://github.com/jbernardo95/riak_kv) `riak_kv` fork

## Compilation 

```
# Install dependencies, compile and build release
$ make rel

# Clean build files 
$ make relclean
```

## Playing with Riak 

```
# Start riak
$ cd rel/riak
$ bin/riak start

# Start console
$ erts-<version>/bin/erl -name riaktest@127.0.0.1 -setcookie riak

(riaktest@127.0.0.1)1> RiakNode = 'riak@127.0.0.1'.

# Plain Riak
(riaktest@127.0.0.1)2> {ok, C} = riak:client_connect(RiakNode). 
(riaktest@127.0.0.1)3> Object = riak_object:new(<<"bucket">>, <<"a">>, 1). 
(riaktest@127.0.0.1)4> C:put(Object, 1).
(riaktest@127.0.0.1)5> {ok, Object1} = C:get(<<"bucket">>, <<"a">>, 1). 
(riaktest@127.0.0.1)6> Value = riak_object:get_value(Object1). 

# Riak + Transactions
(riaktest@127.0.0.1)7> {ok, C} = riak_kv_transactional_client:start_link(RiakNode).
(riaktest@127.0.0.1)8> ok = riak_kv_transactional_client:begin_transaction(C).
(riaktest@127.0.0.1)9> {ok, Object2} = riak_kv_transactional_client:get(RiakNode, <<"bucket">>, <<"a">>, C).
(riaktest@127.0.0.1)11> ok = riak_kv_transactional_client:put(RiakNode, <<"bucket">>, <<"a">>, 2, C).
(riaktest@127.0.0.1)12> riak_kv_transactional_client:commit_transaction(C).

bin/riak stop
```
