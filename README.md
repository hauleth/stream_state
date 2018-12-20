# StreamState

[![CircleCI](https://circleci.com/gh/hauleth/stream_state.svg?style=svg)](https://circleci.com/gh/hauleth/stream_state)
[![codecov](https://codecov.io/gh/hauleth/stream_state/branch/master/graph/badge.svg)](https://codecov.io/gh/hauleth/stream_state)
[![Inch CI](https://inch-ci.org/github/hauleth/stream_state.svg?branch=master)](https://inch-ci.org/github/hauleth/stream_state?branch=master)

Stateful testing implemented on top of [StreamData][stream_data]

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `stream_state` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:stream_state, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/stream_state](https://hexdocs.pm/stream_state).

## Thanks

- @alfert for implementation in [Counter](https://github.com/alfert/counter).
  This library is extraction of code there with some cleanups and minor
  improvements.

## License

See [LICENSE](LICENSE).

[stream_data]: https://hex.pm/packages/stream_data
