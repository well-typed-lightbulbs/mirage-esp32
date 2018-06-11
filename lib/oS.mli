module Env : sig

(** Unikernel environment interface. *)

val argv: unit -> (string array) Lwt.t
(** The command line arguments given to the unikernel. The first
    element is the name of the unikernel binary. The following
    elements are the arguments passed to the unikernel. *)

end

module Esp32 : sig

type esp32_result =
  | ESP32_OK
  | ESP32_AGAIN
  | ESP32_EINVAL
  | ESP32_EUNSPEC

end

module Lifecycle : sig

val await_shutdown_request :
  ?can_poweroff:bool ->
  ?can_reboot:bool ->
  unit -> [`Poweroff | `Reboot] Lwt.t
(** [await_shutdown_request ()] is thread that resolves when the domain is
    asked to shut down.
    The optional [poweroff] (default:[true]) and [reboot] (default:[false])
    arguments can be used to indicate which features the caller wants to
    advertise (however, you can still get a request for a mode you didn't claim
    to support). *)

end

module Main : sig
val run : unit Lwt.t -> unit
val at_enter : (unit -> unit Lwt.t) -> unit
val at_enter_iter : (unit -> unit) -> unit
val at_exit_iter  : (unit -> unit) -> unit
end

module MM : sig
module Heap_pages : sig
  val total: unit -> int
  val used: unit -> int
end
end
module Time : sig

type +'a io = 'a Lwt.t

(** Timeout operations. *)

module Monotonic : sig
  (** Monotonic time is time since boot (dom0 or domU, depending on platform).
   * Unlike Clock.time, it does not go backwards when the system clock is
   * adjusted. *)

  type time_kind = [`Time | `Interval]
  type 'a t constraint 'a = [< time_kind]

  val time : unit -> [`Time] t
  (** Read the current monotonic time. *)

  val ( + ) : 'a t -> [`Interval] t -> 'a t
  val ( - ) : 'a t -> [`Interval] t -> 'a t
  val interval : [`Time] t -> [`Time] t -> [`Interval] t

  (** Conversions. Note: still seconds since boot. *)
  val of_nanoseconds : int64 -> _ t
end

val restart_threads: (unit -> [`Time] Monotonic.t) -> unit
(** [restart_threads time_fun] restarts threads that are sleeping and
    whose wakeup time is before [time_fun ()]. *)

val select_next : unit -> [`Time] Monotonic.t option
(** [select_next ()] is [Some t] where [t] is the earliest time
    when one sleeping thread will wake up, or [None] if there is no
    sleeping threads. *)

val sleep_ns : int64 -> unit Lwt.t
(** [sleep_ns d] Block the current thread for [n] nanoseconds. *)

exception Timeout
(** Exception raised by timeout operations *)

val with_timeout : int64 -> (unit -> 'a Lwt.t) -> 'a Lwt.t
(** [with_timeout d f] is a short-hand for:

    {[
    Lwt.pick [Lwt_unix.timeout d; f ()]
    ]}
*)
end

module Event : sig 

val register_event_number : int -> unit 

val wait_for_event : int -> unit Lwt.t

val work_is_available : unit -> bool

val run : unit -> unit

val wait_for_event : [`Time] Time.Monotonic.t -> unit

end