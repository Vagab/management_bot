Postgrex.Types.define(
  FinanceChatIntegration.PostgrexTypes,
  Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions(),
  []
)
