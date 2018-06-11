
external poll : [`Time] Time.Monotonic.t -> int -> int = "caml_poll"

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
    assert (number > 0 && number < 31);
    event_list := !event_list lor (1 lsl number);
    Lwt_condition.wait (EventMap.find number !event_conditions)

let work_is_available () = poll (Time.Monotonic.time ()) !event_list != 0

let run () = 
    let rec check evt = function 
        | n when n < 31 -> 
            if evt land (1 lsl n) != 0 then Lwt_condition.broadcast (EventMap.find n !event_conditions) ();
            check evt (n+1)
        | _ -> ()
    in
    let event_list_copy = !event_list in 
    event_list := 0;
    let events = poll (Time.Monotonic.time ()) event_list_copy in 
    check events 0

let wait_for_event timeout = 
    ignore (poll timeout !event_list)
