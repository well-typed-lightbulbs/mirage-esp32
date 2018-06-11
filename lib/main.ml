open Lwt

external initialize : unit -> unit = "caml_poll_initialize"

(* Hacky *)
[@@@ocaml.warning "-3"]
module Lwt_sequence = Lwt_sequence
[@@@ocaml.warning "+3"]

let exit_hooks = Lwt_sequence.create ()
let enter_hooks = Lwt_sequence.create ()
let exit_iter_hooks = Lwt_sequence.create ()
let enter_iter_hooks = Lwt_sequence.create ()

let rec call_hooks hooks  =
  match Lwt_sequence.take_opt_l hooks with
    | None ->
        return ()
    | Some f ->
        (* Run the hooks in parallel *)
        let _ =
          Lwt.catch f
          (fun exn ->
            Printf.printf "ERROR: call_hooks(): Unhandled exception: %s\n%!" (Printexc.to_string exn);
            return ()) in
        call_hooks hooks


let err exn =
  Printf.eprintf "main: %s\n%s" (Printexc.to_string exn) (Printexc.get_backtrace ()) ;
  exit 1

(* Execute one iteration and register a callback function *)
let run t =
  initialize ();
  Printf.printf "Starting event loop.\n";
  flush stdout;
  let t = call_hooks enter_hooks <&> t in
  let rec aux () =
    Lwt.wakeup_paused ();
    Time.restart_threads Time.Monotonic.time;
    match (try Lwt.poll t with exn -> err exn) with
    | Some () ->
        ()
    | None ->
        if Event.work_is_available () then 
          begin
            (* Call enter hooks. *)
            Lwt_sequence.iter_l (fun f -> f ()) enter_iter_hooks;
            (* Some I/O is possible, wake up threads and continue. *)
            Event.run ();
            (* Call leave hooks. *)
            Lwt_sequence.iter_l (fun f -> f ()) exit_iter_hooks;
            aux () 
          end
        else
          begin
            let timeout =
              match Time.select_next () with
              |None -> Time.Monotonic.(time () + of_nanoseconds 86_400_000_000_000L) (* one day = 24 * 60 * 60 s *)
              |Some tm -> tm
            in 
              Event.wait_for_event timeout;
              aux ()
          end
  in
  aux ();
  Printf.printf "Leaving event loop.\n";
  flush stdout

let () = at_exit (fun () -> run (call_hooks exit_hooks))
let at_exit f = ignore (Lwt_sequence.add_l f exit_hooks)
let at_enter f = ignore (Lwt_sequence.add_l f enter_hooks)
let at_exit_iter f = ignore (Lwt_sequence.add_l f exit_iter_hooks)
let at_enter_iter f = ignore (Lwt_sequence.add_l f enter_iter_hooks)