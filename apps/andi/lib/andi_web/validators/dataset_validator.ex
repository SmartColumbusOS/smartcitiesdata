defmodule AndiWeb.DatasetValidator do
  @moduledoc "Used to validate datasets"

  import Andi, only: [instance_name: 0]

  def validate(dataset) do
    case SimplyValidate.validate(dataset, [validate_org_name(), validate_data_name(), already_exists!()]) do
      [] -> :valid
      errors -> {:invalid, errors}
    end
  end

  def validate_org_name do
    {&String.contains?(&1.technical.orgName, "-"), "orgName cannot contain dashes", false}
  end

  def validate_data_name do
    {&String.contains?(&1.technical.dataName, "-"), "dataName cannot contain dashes", false}
  end

  def already_exists! do
    {&check_already_exists/1, "Existing dataset has the same orgName and dataName", false}
  end

  #########################
  ##  Private Functions  ##
  #########################
  defp check_already_exists(dataset) do
    existing_datasets = Brook.get_all_values!(instance_name(), :dataset)

    Enum.any?(existing_datasets, fn existing_dataset ->
      different_ids(dataset, existing_dataset) &&
        same_system_name(dataset, existing_dataset)
    end)
  end

  defp same_system_name(a, b), do: a.technical.systemName == b.technical.systemName
  defp different_ids(a, b), do: a.id != b.id
end