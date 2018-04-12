defmodule Ellie.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ellie.Revision

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :settings, Ellie.Settings
    field :terms_version, :integer
    has_many :revisions, Revision
    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:settings, :terms_version])
    |> validate_required([:settings])
  end
end
