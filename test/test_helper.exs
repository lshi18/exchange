ExUnit.start()

defmodule TestHelpers do
  def new(order) do
    Map.merge(order, %{instruction: :new})
  end

  def update(order) do
    Map.merge(order, %{instruction: :update})
  end

  def delete(order) do
    Map.merge(order, %{instruction: :delete})
  end

  def ask_order(price_level_index, price_quantity \\ []) do
    order(:ask, price_level_index, price_quantity)
  end

  def bid_order(price_level_index, price_quantity \\ []) do
    order(:bid, price_level_index, price_quantity)
  end

  defp order(side, price_level_index, price_quantity) do
    Enum.into(price_quantity, %{side: side, price_level_index: price_level_index})
  end
end
