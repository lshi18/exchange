defmodule ExchangeTest do
  use ExUnit.Case
  doctest Exchange

  import Exchange, only: [start_link: 0, start_link: 1, send_instruction: 2, order_book: 2]

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

  setup context do
    if context[:with_persistence] do
      filename = Path.join(System.tmp_dir(), to_string(DateTime.utc_now()))
      {:ok, ex_pid} = start_link(store: %FileStore{filename: filename})
      [p_filename: filename, ex_pid: ex_pid]
    else
      {:ok, ex_pid} = start_link()
      [ex_pid: ex_pid]
    end
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

  test "insert with index which has been created as a zero-valued price level on a \"gap-producing\" insertion",
       %{
         ex_pid: ex_pid
       } do
    events = [
      # Create a zero-valued price level at index = 1.
      order(:ask, price: test_price(1), quantity: test_quantity(1)) |> new(2),
      # insert at price level = 1
      order(:ask, price: test_price(2), quantity: test_quantity(2)) |> new(1)
    ]

    send_events(ex_pid, events)

    # Should it behave as the current implementation?
    assert [
             %{
               ask_price: test_price(2),
               ask_quantity: test_quantity(2),
               bid_price: 0,
               bid_quantity: 0
             },
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
           ] == order_book(ex_pid, 3)

    # Or should it behave like below?
    # assert [
    #          %{
    #            ask_price: test_price(2),
    #            ask_quantity: test_quantity(2),
    #            bid_price: 0,
    #            bid_quantity: 0
    #          },
    #          %{
    #            ask_price: test_price(1),
    #            ask_quantity: test_quantity(1),
    #            bid_price: 0,
    #            bid_quantity: 0
    #          }
    #        ] == order_book(ex_pid, 2)
  end

  test "update an zero-valued price level created on \"gap-producing\" insertion", %{
    ex_pid: ex_pid
  } do
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

  @tag :with_persistence
  test "with persistent store", %{ex_pid: ex_pid, p_filename: filename} do
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
             "new;1;ask;1;10",
             "new;1;bid;2;20",
             "new;2;ask;3;30",
             "new;2;bid;4;40",
             "new;3;ask;5;50",
             "new;3;bid;6;60"
           ] == filename |> File.read!() |> String.trim_trailing("\n") |> String.split("\n")
  end
end
