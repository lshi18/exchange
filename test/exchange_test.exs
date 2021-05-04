defmodule ExchangeTest do
  use ExUnit.Case
  doctest Exchange

  import Exchange, only: [start_link: 0, send_instruction: 2, order_book: 2]

  import TestHelpers,
    only: [new: 1, delete: 1, update: 1, ask_order: 2, ask_order: 1, bid_order: 2]

  @prices [30, 40, 50, 60, 70, 80]
  @quantities [45, 55, 65, 75, 85, 95]

  defp test_price(n) do
    Enum.at(@prices, n + 1)
  end

  defp test_quantity(n) do
    Enum.at(@quantities, n + 1)
  end

  def send_events(ex_pid, events) do
    Enum.each(events, fn event -> Exchange.send_instruction(ex_pid, event) end)
  end

  setup do
    {:ok, ex_pid} = start_link()

    events = []

    send_events(ex_pid, events)

    [ex_pid: ex_pid]
  end

  @tag :skip
  test "a price level that has not been provided should have values of zero", %{ex_pid: ex_pid} do
    events = [
      new(ask_order(1, price: test_price(1), quantity: test_quantity(1)))
    ]

    send_events(ex_pid, events)

    assert [
             %{
               ask_price: test_price(1),
               ask_quantity: test_quantity(1),
               bid_price: 0,
               bid_quantity: 0
             },
             %{
               ask_price: 0,
               ask_quantity: 0,
               bid_price: 0,
               bid_quantity: 0
             }
           ] == order_book(ex_pid, 2)
  end

  @tag :skip
  test "insert a new order with existed price level index", %{ex_pid: ex_pid} do
    events = [
      new(ask_order(1, price: test_price(1), quantity: test_quantity(1))),
      new(bid_order(1, price: test_price(2), quantity: test_quantity(2))),
      new(ask_order(1, price: test_price(3), quantity: test_quantity(3)))
    ]

    send_events(ex_pid, events)

    assert [
             %{
               ask_price: test_price(3),
               ask_quantity: test_quantity(3),
               bid_price: test_price(2),
               bid_quantity: test_quantity(2)
             },
             %{
               ask_price: test_price(1),
               ask_quantity: test_quantity(1),
               bid_price: 0,
               bid_quantity: 0
             }
           ] == order_book(ex_pid, 2)
  end

  @tag :skip
  test "delete an existing order", %{ex_pid: ex_pid} do
    events = [
      new(ask_order(1, price: test_price(1), quantity: test_quantity(1))),
      new(bid_order(1, price: test_price(2), quantity: test_quantity(2))),
      new(ask_order(2, price: test_price(3), quantity: test_quantity(3))),
      delete(ask_order(1))
    ]

    send_events(ex_pid, events)

    assert [
             %{
               ask_price: test_price(3),
               ask_quantity: test_quantity(3),
               bid_price: test_price(2),
               bid_quantity: test_quantity(2)
             }
           ] == order_book(ex_pid, 1)
  end

  @tag :skip
  test "new orders with nonconsecutive price level index, automatically adjust the index and fill the gap",
       %{ex_pid: ex_pid} do
    events = [
      new(ask_order(1, price: test_price(1), quantity: test_quantity(1))),
      new(ask_order(3, price: test_price(3), quantity: test_quantity(3))),
      new(bid_order(1, price: test_price(2), quantity: test_quantity(2))),
      new(bid_order(4, price: test_price(4), quantity: test_quantity(4)))
    ]

    send_events(ex_pid, events)

    assert [
             %{
               ask_price: test_price(1),
               ask_quantity: test_quantity(1),
               bid_price: test_price(2),
               bid_quantity: test_quantity(2)
             },
             %{
               ask_price: test_price(3),
               ask_quantity: test_quantity(3),
               bid_price: test_price(4),
               bid_quantity: test_quantity(4)
             }
           ] == order_book(ex_pid, 2)
  end

  @tag :skip
  test "book_depth is smaller than the total number of price levels", %{ex_pid: ex_pid} do
    events = [
      new(ask_order(1, price: test_price(1), quantity: test_quantity(1))),
      new(bid_order(1, price: test_price(2), quantity: test_quantity(2))),
      new(ask_order(2, price: test_price(3), quantity: test_quantity(3))),
      new(bid_order(2, price: test_price(4), quantity: test_quantity(4))),
      new(ask_order(3, price: test_price(5), quantity: test_quantity(5))),
      new(bid_order(3, price: test_price(6), quantity: test_quantity(6)))
    ]

    send_events(ex_pid, events)

    assert [
             %{
               ask_price: test_price(1),
               ask_quantity: test_quantity(1),
               bid_price: test_price(2),
               bid_quantity: test_quantity(2)
             },
             %{
               ask_price: test_price(3),
               ask_quantity: test_quantity(3),
               bid_price: test_price(4),
               bid_quantity: test_quantity(4)
             }
           ] == order_book(ex_pid, 2)
  end

  @tag :skip
  test "return an error when updating a price level that has not yet been created", %{ex_pid: ex_pid} do
    event = update(ask_order(1, price: test_price(1), quantity: test_quantity(1)))

    assert {:error, :price_level_not_exist} = send_instruction(ex_pid, event)
  end

  @tag :skip
  test "return an error when deleting a price level that has not yet been created", %{ex_pid: ex_pid} do
    event = delete(ask_order(1))

    assert {:error, :price_level_not_exist} = send_instruction(ex_pid, event)
  end
end
