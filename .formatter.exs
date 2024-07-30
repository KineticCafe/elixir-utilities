[
  inputs: [
    "mix.exs",
    ".*.exs",
    "config/*.exs"
  ],
  import_deps: [
    :ecto,
    :ecto_sql,
    :nimble_parsec,
    :tesla,
    :typedstruct
  ]
]
