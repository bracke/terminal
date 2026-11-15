package Terminal.App.Platform_Launcher.Testing is
   procedure Dispatch
     (Preferred_Program : String;
      Fallback_Program  : String;
      URI               : String;
      Status            : out Launch_Status;
      Start             : not null access procedure
        (Program : String;
         URI     : String;
         Status  : out Launch_Status));

   procedure Launch_Direct
     (Program : String;
      URI     : String;
      Status  : out Launch_Status);
   procedure Poll_Launches;
   function Can_Track_Children return Boolean;
   function Pending_Count return Natural;
   function Child_Tracker_Admission_Valid return Boolean;
   function Child_Tracker_Recovery_Valid return Boolean;
   function Child_Tracker_Reservation_Valid return Boolean;
   function Child_Tracker_Capacity_Valid return Boolean;
end Terminal.App.Platform_Launcher.Testing;
