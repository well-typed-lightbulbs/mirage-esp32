open Lwt.Infix

external c_poll : [`Time] Time.Monotonic.t -> int -> int = "caml_poll"

let event_list = ref 0

module EventMap = Map.Make(
    struct 
        let compare = Pervasives.compare
        type t = int
    end
)

let event_conditions = ref EventMap.empty

let register_event_number num = 
    if EventMap.mem num !event_conditions then
        Printf.printf "Event already registered %d\n%!" num 
    else
        event_conditions := EventMap.add num (Lwt_condition.create ()) !event_conditions


let wait_for_event number = 
    assert (number >= 0 && number < 31);
    Logs.info (fun f -> f "wait_for_event: %d %x" number !event_list);
    event_list := !event_list lor (1 lsl number);
    Lwt_condition.wait (EventMap.find number !event_conditions) >>= fun _ ->
    Logs.info (fun f -> f "wait_for_event triggered: %d" number);
    Lwt.return_unit

let work_is_available () = c_poll (Time.Monotonic.time ()) !event_list != 0

let run () = 
    let rec check evt = function 
        | n when n < 31 -> 
            if evt land (1 lsl n) != 0 then 
                begin
                    Lwt_condition.broadcast (EventMap.find n !event_conditions) ();
                    Logs.info (fun f -> f "poll triggered: %d" n);
                end;
            check evt (n+1)
        | _ -> ()
    in
    let event_list_copy = !event_list in 
    event_list := 0;
    let events = c_poll (Time.Monotonic.time ()) event_list_copy in 
    check events 0

let poll timeout = 
    ignore (c_poll timeout !event_list)
