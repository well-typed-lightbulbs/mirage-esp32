open Lwt

type +'a io = 'a Lwt.t

module Monotonic = struct
  type time_kind = [`Time | `Interval]
  type 'a t = int64 constraint 'a = [< time_kind]
  (* Time in microseconds. *)
  external time : unit -> int64 = "caml_get_monotonic_time"

  let of_nanoseconds x = Int64.div x 1000L

  let ( + ) = ( Int64.add )
  let ( - ) = ( Int64.sub )
  let interval = ( Int64.sub )
end

(* +-----------------------------------------------------------------+
   | Sleepers                                                        |
   +-----------------------------------------------------------------+ *)

type sleep = {
  time : [`Time] Monotonic.t;
  mutable canceled : bool;
  thread : unit Lwt.u;
}

module SleepQueue = 
    Psq.Make 
        (struct 
            type t = int 
            let compare a b = compare a b
        end)
        (struct 
            type t = sleep 
            let compare { time = t1; _} { time = t2; _} = compare t1 t2 
         end)

let sleep_queue = ref SleepQueue.empty

(* Sleepers added since the last iteration of the main loop:
   They are not added immediatly to the main sleep queue in order to
   prevent them from being wakeup immediatly by [restart_threads].
*)
let new_sleeps = ref []

let id = ref 0
let new_id () =
    incr id;
    !id

let sleep_ns d =
  let (res, w) = Lwt.task () in
  let t = Monotonic.(time () + of_nanoseconds d) in
  let sleeper = { time = t; canceled = false; thread = w } in
  new_sleeps := sleeper :: !new_sleeps;
  Lwt.on_cancel res (fun _ -> sleeper.canceled <- true);
  res

exception Timeout

let timeout d = sleep_ns d >>= fun () -> Lwt.fail Timeout

let with_timeout d f = Lwt.pick [timeout d; Lwt.apply f ()]

let in_the_past now t =
  t = 0L || t <= now ()

let unpack = function 
    | Some t -> t 
    | None -> failwith "time.ml: unpack failed."

let rec restart_threads now =
  match SleepQueue.min !sleep_queue with
    | Some (_, { canceled = true; _ }) ->
        sleep_queue := unpack (SleepQueue.rest !sleep_queue);
        restart_threads now
    | Some (_, { time = time; thread = thread; _ }) when in_the_past now time ->
        sleep_queue := unpack (SleepQueue.rest !sleep_queue);
        Lwt.wakeup thread ();
        restart_threads now
    | _ ->
        ()

(* +-----------------------------------------------------------------+
   | Event loop                                                      |
   +-----------------------------------------------------------------+ *)

let min_timeout a b = match a, b with
  | None, b -> b
  | a, None -> a
  | Some a, Some b -> Some(min a b)

let rec get_next_timeout () =
  match SleepQueue.min !sleep_queue with
    | Some (_, { canceled = true; _ }) ->
        sleep_queue := unpack (SleepQueue.rest !sleep_queue);
        get_next_timeout ()
    | Some (_, { time = time; _ }) ->
        Some time
    | None ->
        None

let select_next () =
  (* Transfer all sleepers added since the last iteration to the main
     sleep queue: *)
  sleep_queue :=
    List.fold_left
      (fun q e -> SleepQueue.add (new_id ()) e q) !sleep_queue !new_sleeps;
  new_sleeps := [];
get_next_timeout ()