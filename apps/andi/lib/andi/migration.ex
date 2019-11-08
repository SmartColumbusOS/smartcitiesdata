defmodule Andi.Migration do
  import Andi, only: [instance_name: 0]

  @instance Andi.instance_name()
  @migrations ["modified_date_migration"]

  def init do
    Enum.each(@migrations, fn migration_type ->
      if is_nil(Brook.get!(@instance, :migration, migration_type)) do
        Brook.Event.send(@instance, "migration:#{migration_type}", :andi, true)
      end
    end)
  end
end
