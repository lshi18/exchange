defmodule ExchangeTest do
  use ExUnit.Case
  doctest Exchange

  import Exchange, only: [start_link: 0, send_instruction: 2, order_book: 2]

  import TestHelpers,
    only: [new: 2, delete: 2, update: 2, order: 2, order: 1]

  @prices [1, 2, 3, 4, 5, 6]
  @quantities [10, 20, 30, 40, 50, 60]

  defp test_price(n) do
    Enum.at(@prices, n - 1)
  end

  defp test_quantity(n) do
    Enum.at(@quantities, n - 1)
  end

  def send_events(ex_pid, events) do
    Enum.each(events, fn event -> Exchange.send_instruction(ex_pid, event) end)
  end

  setup do
    {:ok, ex_pid} = start_link()

    [ex_pid: ex_pid]
  end

  test "a price level that has not been provided should have values of zero", %{ex_pid: ex_pid} do
    events = [
      order(:ask, price: test_price(1), quantity: test_quantity(1)) |> new(1)
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

  test "insert a new order with existed price level index should shift up price levels with equal and larger index",
       %{ex_pid: ex_pid} do
    events = [
      order(:ask, price: test_price(1), quantity: test_quantity(1)) |> new(1),
      order(:bid, price: test_price(2), quantity: test_quantity(2)) |> new(1),
      order(:ask, price: test_price(3), quantity: test_quantity(3)) |> new(1)
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

  test "update an zero-valued price level created on \"gap-producing\" insertion", %{ex_pid: ex_pid} do
    # Create a zero-valued price level at index = 1.
    events = [
      order(:ask, price: test_price(1), quantity: test_quantity(1)) |> new(2)
    ]

    send_events(ex_pid, events)

    assert [
             %{
               ask_price: 0,
               ask_quantity: 0,
               bid_price: 0,
               bid_quantity: 0
             },
             %{
               ask_price: test_price(1),
               ask_quantity: test_quantity(1),
               bid_price: 0,
               bid_quantity: 0
             }
           ] == order_book(ex_pid, 2)

    # Update ask order at index 1
    events = [
      order(:ask, price: test_price(2), quantity: test_quantity(2)) |> update(1)
    ]

    send_events(ex_pid, events)

    assert [
             %{
               ask_price: test_price(2),
               ask_quantity: test_quantity(2),
               bid_price: 0,
               bid_quantity: 0
             },
             %{
               ask_price: test_price(1),
               ask_quantity: test_quantity(1),
               bid_price: 0,
               bid_quantity: 0
             }
           ] == order_book(ex_pid, 2)
  end

  test "delete an existing price level (order)", %{ex_pid: ex_pid} do
    events = [
      order(:ask, price: test_price(1), quantity: test_quantity(1)) |> new(1),
      order(:bid, price: test_price(2), quantity: test_quantity(2)) |> new(1),
      order(:ask, price: test_price(3), quantity: test_quantity(3)) |> new(2),
      order(:ask) |> delete(1)
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

  test "new orders with nonconsecutive price level index, fill the \"gap\" with zero-valued orders",
       %{ex_pid: ex_pid} do
    events = [
      order(:ask, price: test_price(1), quantity: test_quantity(1)) |> new(1),
      order(:ask, price: test_price(3), quantity: test_quantity(3)) |> new(3),
      order(:bid, price: test_price(2), quantity: test_quantity(2)) |> new(1),
      order(:bid, price: test_price(4), quantity: test_quantity(4)) |> new(4)
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
               ask_price: 0,
               ask_quantity: 0,
               bid_price: 0,
               bid_quantity: 0
             },
             %{
               ask_price: test_price(3),
               ask_quantity: test_quantity(3),
               bid_price: 0,
               bid_quantity: 0
             },
             %{
               ask_price: 0,
               ask_quantity: 0,
               bid_price: test_price(4),
               bid_quantity: test_quantity(4)
             }
           ] == order_book(ex_pid, 4)
  end

  test "book_depth is smaller than the total number of price levels", %{ex_pid: ex_pid} do
    events = [
      order(:ask, price: test_price(1), quantity: test_quantity(1)) |> new(1),
      order(:bid, price: test_price(2), quantity: test_quantity(2)) |> new(1),
      order(:ask, price: test_price(3), quantity: test_quantity(3)) |> new(2),
      order(:bid, price: test_price(4), quantity: test_quantity(4)) |> new(2),
      order(:ask, price: test_price(5), quantity: test_quantity(5)) |> new(3),
      order(:bid, price: test_price(6), quantity: test_quantity(6)) |> new(3)
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

  test "delete existed price level should shift down price levels with equal and larger index", %{
    ex_pid: ex_pid
  } do
    events = [
      order(:ask, price: test_price(1), quantity: test_quantity(1)) |> new(1),
      order(:bid, price: test_price(2), quantity: test_quantity(2)) |> new(1),
      order(:ask, price: test_price(3), quantity: test_quantity(3)) |> new(2),
      order(:bid, price: test_price(4), quantity: test_quantity(4)) |> new(2),
      order(:ask) |> delete(1)
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
               ask_price: 0,
               ask_quantity: 0,
               bid_price: test_price(4),
               bid_quantity: test_quantity(4)
             }
           ] == order_book(ex_pid, 2)
  end

  test "return an error when updating a price level that has not yet been created", %{
    ex_pid: ex_pid
  } do
    event = order(:ask, price: test_price(1), quantity: test_quantity(1)) |> update(1)
    assert {:error, :price_level_not_exist} = send_instruction(ex_pid, event)

    event = order(:bid, price: test_price(1), quantity: test_quantity(1)) |> update(1)
    assert {:error, :price_level_not_exist} = send_instruction(ex_pid, event)
  end

  test "return an error when deleting a price level that has not yet been created", %{
    ex_pid: ex_pid
  } do
    event = order(:ask) |> delete(1)
    assert {:error, :price_level_not_exist} = send_instruction(ex_pid, event)

    event = order(:bid) |> delete(1)
    assert {:error, :price_level_not_exist} = send_instruction(ex_pid, event)
  end
end
