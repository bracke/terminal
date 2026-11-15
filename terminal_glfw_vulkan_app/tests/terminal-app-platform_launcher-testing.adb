with Terminal.App.Child_Tracker;

package body Terminal.App.Platform_Launcher.Testing is
   package Tracker renames Terminal.App.Child_Tracker;
   procedure Dispatch
     (Preferred_Program : String;
      Fallback_Program  : String;
      URI               : String;
      Status            : out Launch_Status;
      Start             : not null access procedure
        (Program : String;
         URI     : String;
         Status  : out Launch_Status)) is
   begin
      Dispatch_URI
        (Preferred_Program,
         Fallback_Program,
         URI,
         Status,
         Start);
   end Dispatch;

   procedure Launch_Direct
     (Program : String;
      URI     : String;
      Status  : out Launch_Status) is
   begin
      Launch_Program (Program, URI, Status);
   end Launch_Direct;

   procedure Poll_Launches is
   begin
      Terminal.App.Platform_Launcher.Poll;
   end Poll_Launches;

   function Can_Track_Children return Boolean is
     (Child_Tracking_Available);

   function Pending_Count return Natural is
     (Pending_Launch_Count);

   function Child_Tracker_Admission_Valid return Boolean is
      Children    : Tracker.Registry;
      Reservation : Tracker.Reservation;
   begin
      for I in 1 .. Tracker.Max_Admission_Load loop
         Children.Reserve (Reservation);
         if not Tracker.Granted (Reservation) then
            return False;
         end if;
         Children.Commit (Tracker.Process_ID (I), Reservation);
      end loop;
      Children.Reserve (Reservation);
      return not Tracker.Granted (Reservation)
        and then Children.Count = Tracker.Max_Admission_Load
        and then Children.Admission_Load = Tracker.Max_Admission_Load;
   end Child_Tracker_Admission_Valid;

   function Child_Tracker_Recovery_Valid return Boolean is
      Children     : Tracker.Registry;
      Reservation  : Tracker.Reservation;
      First_Report : Boolean;
   begin
      for I in 1 .. Tracker.Max_Admission_Load loop
         Children.Reserve (Reservation);
         if not Tracker.Granted (Reservation) then
            return False;
         end if;
         Children.Commit (Tracker.Process_ID (I), Reservation);
      end loop;
      Children.Note_Poll_Error (1, First_Report);
      if not First_Report
        or else Children.Admission_Load /= Tracker.Max_Admission_Load - 1
      then
         return False;
      end if;
      Children.Note_Poll_Error (1, First_Report);
      if First_Report then
         return False;
      end if;

      Children.Reserve (Reservation);
      if not Tracker.Granted (Reservation) then
         return False;
      end if;
      Children.Commit
        (Tracker.Process_ID (Tracker.Max_Admission_Load + 1), Reservation);
      Children.Note_Poll_Success (1);
      if Children.Count /= Tracker.Max_Admission_Load + 1
        or else Children.Admission_Load /= Tracker.Max_Admission_Load + 1
      then
         return False;
      end if;
      Children.Reserve (Reservation);
      if Tracker.Granted (Reservation) then
         return False;
      end if;

      Children.Remove (1);
      Children.Remove
        (Tracker.Process_ID (Tracker.Max_Admission_Load + 1));
      Children.Note_Poll_Error (2, First_Report);
      Children.Note_Poll_Success (2);
      Children.Note_Poll_Error (2, First_Report);
      if not First_Report then
         return False;
      end if;
      return True;
   end Child_Tracker_Recovery_Valid;

   function Child_Tracker_Reservation_Valid return Boolean is
      Children : Tracker.Registry;
      task Holder is
         entry Reserved;
      end Holder;
      task body Holder is
         Reservation : Tracker.Reservation;
      begin
         Children.Reserve (Reservation);
         accept Reserved;
         delay 60.0;
      end Holder;
   begin
      Holder.Reserved;
      abort Holder;
      return Children.Count = 0 and then Children.Admission_Load = 0;
   end Child_Tracker_Reservation_Valid;

   function Child_Tracker_Capacity_Valid return Boolean is
      Children     : Tracker.Registry;
      Reservation  : Tracker.Reservation;
      First_Report : Boolean;
   begin
      for I in 1 .. Tracker.Max_Tracked_Children loop
         Children.Reserve (Reservation);
         if not Tracker.Granted (Reservation) then
            return False;
         end if;
         Children.Commit (Tracker.Process_ID (I), Reservation);
         Children.Note_Poll_Error
           (Tracker.Process_ID (I), First_Report);
      end loop;
      Children.Reserve (Reservation);
      return not Tracker.Granted (Reservation)
        and then Children.Count = Tracker.Max_Tracked_Children
        and then Children.Admission_Load = 0;
   end Child_Tracker_Capacity_Valid;
end Terminal.App.Platform_Launcher.Testing;
