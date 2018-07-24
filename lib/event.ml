open Lwt.Infix

(*  This event system encodes event as bits in a bitset. 
    Thus allowing up to 31 events registered. *)

(*  Wait for a particular set of events with a given timeout. 
    Events to wait for are given as a bitset. *)
external c_poll : [`Time] Time.Monotonic.t -> int -> int = "caml_poll"

(*  Events that are waited for and haven't been triggered. *)
let event_list = ref 0

module EventMap = Map.Make(
    struct 
        let compare = Pervasives.compare
        type t = int
    end
)

(* Map from event number to Lwt.condition to wake lwt threads on event.*)
let event_conditions = ref EventMap.empty

(* Create a condition per event number. *)
let register_event_number num = 
    if EventMap.mem num !event_conditions then
        Printf.printf "Event already registered %d\n%!" num 
    else
        event_conditions := EventMap.add num (Lwt_condition.create ()) !event_conditions

(* Wait for an event number. *)
let wait_for_event number = 
    assert (number >= 0 && number < 31);
    event_list := !event_list lor (1 lsl number);
    Lwt_condition.wait (EventMap.find number !event_conditions) >>= fun _ ->
    Lwt.return_unit

(* Check if some process can be waken up. *)
let work_is_available () = c_poll (Time.Monotonic.time ()) !event_list != 0

(* Wake up processes on events. *)
let run () = 
    let rec check evt = function 
        | n when n < 31 -> 
            if evt land (1 lsl n) != 0 then 
                begin
                    event_list := !event_list lxor (1 lsl n);
                    Lwt_condition.broadcast (EventMap.find n !event_conditions) ();
                end;
            check evt (n+1)
        | _ -> ()
    in
    let events = c_poll (Time.Monotonic.time ()) !event_list in 
    check events 0

(* Wait for an event. *)
let poll timeout = 
    ignore (c_poll timeout !event_list)
