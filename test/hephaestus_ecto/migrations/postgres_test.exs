defmodule HephaestusEcto.Migrations.PostgresTest do
  use ExUnit.Case, async: false

  alias HephaestusEcto.Migrations.Postgres
  alias HephaestusEcto.TestRepo

  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(TestRepo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    prefix = "migration_test_#{System.unique_integer([:positive])}"
    TestRepo.query!("CREATE SCHEMA #{prefix}")

    %{prefix: prefix}
  end

  describe "migrated_version/1" do
    test "reads table comments from a non-public prefix", %{prefix: prefix} do
      try do
        TestRepo.query!("CREATE TABLE #{prefix}.workflow_instances (id uuid PRIMARY KEY)")
        TestRepo.query!("COMMENT ON TABLE #{prefix}.workflow_instances IS '7'")

        assert Postgres.migrated_version(repo: TestRepo, prefix: prefix) == 7
      after
        TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
      end
    end

    test "returns 0 when table does not exist", %{prefix: prefix} do
      try do
        assert Postgres.migrated_version(repo: TestRepo, prefix: prefix) == 0
      after
        TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
      end
    end

    test "returns correct version on public schema" do
      version = Postgres.migrated_version(repo: TestRepo, prefix: "public")
      assert version == Postgres.current_version()
    end

    test "returns 0 when comment is NULL on public schema" do
      TestRepo.query!("COMMENT ON TABLE workflow_instances IS NULL", [], log: false)

      try do
        assert 0 = Postgres.migrated_version(repo: TestRepo, prefix: "public")
      after
        TestRepo.query!(
          "COMMENT ON TABLE \"public\".workflow_instances IS '#{Postgres.current_version()}'",
          [],
          log: false
        )
      end
    end
  end

  describe "up/1 no-op" do
    test "returns :ok when already at current version" do
      assert :ok = Postgres.up(repo: TestRepo, prefix: "public")
    end
  end

  describe "V03 migration" do
    test "up/1 converts id from uuid to varchar(255)", %{prefix: prefix} do
      try do
        TestRepo.query!("CREATE TABLE #{prefix}.workflow_instances (id uuid PRIMARY KEY)")

        assert %{data_type: "uuid", character_maximum_length: nil} = id_column(prefix)

        assert :ok =
                 Ecto.Migration.Runner.run(
                   TestRepo,
                   TestRepo.config(),
                   30_001,
                   __MODULE__.V03DirectMigration,
                   :forward,
                   :up,
                   :up,
                   prefix: prefix,
                   log: false,
                   log_migrations_sql: false
                 )

        assert %{data_type: "character varying", character_maximum_length: 255} =
                 id_column(prefix)
      after
        TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
      end
    end

    test "up/1 is idempotent when id is already varchar(255)", %{prefix: prefix} do
      try do
        TestRepo.query!(
          "CREATE TABLE #{prefix}.workflow_instances (id varchar(255) PRIMARY KEY)"
        )

        assert :ok =
                 Ecto.Migration.Runner.run(
                   TestRepo,
                   TestRepo.config(),
                   30_002,
                   __MODULE__.V03DirectMigration,
                   :forward,
                   :up,
                   :up,
                   prefix: prefix,
                   log: false,
                   log_migrations_sql: false
                 )

        assert :ok =
                 Ecto.Migration.Runner.run(
                   TestRepo,
                   TestRepo.config(),
                   30_003,
                   __MODULE__.V03DirectMigration,
                   :forward,
                   :up,
                   :up,
                   prefix: prefix,
                   log: false,
                   log_migrations_sql: false
                 )

        assert %{data_type: "character varying", character_maximum_length: 255} =
                 id_column(prefix)
      after
        TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
      end
    end

    test "up/1 migrates a fresh schema from version 1 to 3", %{prefix: prefix} do
      try do
        assert 0 = Postgres.migrated_version(repo: TestRepo, prefix: prefix)

        assert :ok =
                 Ecto.Migration.Runner.run(
                   TestRepo,
                   TestRepo.config(),
                   30_004,
                   __MODULE__.UpToV03Migration,
                   :forward,
                   :up,
                   :up,
                   prefix: prefix,
                   log: false,
                   log_migrations_sql: false
                 )

        assert 3 = Postgres.migrated_version(repo: TestRepo, prefix: prefix)
        assert %{data_type: "character varying", character_maximum_length: 255} =
                 id_column(prefix)
      after
        TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
      end
    end
  end

  describe "down/1" do
    test "returns :ok when target version is above current version", %{prefix: prefix} do
      try do
        assert :ok = Postgres.down(repo: TestRepo, prefix: prefix, version: 2)
      after
        TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
      end
    end
  end

  describe "prefix validation" do
    test "rejects invalid prefix" do
      assert_raise ArgumentError, fn ->
        Postgres.up(prefix: "Robert'; DROP TABLE --", repo: TestRepo)
      end
    end

    test "rejects prefix with special characters" do
      assert_raise ArgumentError, fn ->
        Postgres.up(prefix: "my-prefix", repo: TestRepo)
      end
    end
  end

  defp id_column(prefix) do
    result =
      TestRepo.query!(
        """
        SELECT data_type, character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = $1
        AND table_name = 'workflow_instances'
        AND column_name = 'id'
        """,
        [prefix]
      )

    case result.rows do
      [[data_type, character_maximum_length]] ->
        %{data_type: data_type, character_maximum_length: character_maximum_length}

      _ ->
        flunk("workflow_instances.id column metadata not found for prefix #{prefix}")
    end
  end

  defmodule V03DirectMigration do
    use Ecto.Migration

    def up do
      HephaestusEcto.Migrations.Postgres.V03.up(%{
        prefix: prefix(),
        quoted_prefix: inspect(prefix())
      })
    end
  end

  defmodule UpToV03Migration do
    use Ecto.Migration

    def up do
      HephaestusEcto.Migration.up(version: 3, prefix: prefix())
    end
  end
end
