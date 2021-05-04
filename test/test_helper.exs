ExUnit.start()

defmodule TestHelpers do
  def new(order, price_level_index) do
    Map.merge(order, %{instruction: :new, price_level_index: price_level_index})
  end

  def update(order, price_level_index) do
    Map.merge(order, %{instruction: :update, price_level_index: price_level_index})
  end

  def delete(order, price_level_index) do
    Map.merge(order, %{instruction: :delete, price_level_index: price_level_index})
  end

  def order(side, price_quantity \\ []) do
    Enum.into(price_quantity, %{side: side})
  end
end
