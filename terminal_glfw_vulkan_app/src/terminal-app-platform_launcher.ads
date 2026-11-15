package Terminal.App.Platform_Launcher is
   type Launch_Status is
     (Opened,
      Launcher_Unavailable,
      Launch_Failed);

   procedure Open_URI
     (URI    : String;
      Status : out Launch_Status);
   procedure Show_Notification
     (Title  : String;
      Message : String;
      Status : out Launch_Status);
   procedure Open_Window
     (Workspace_Path : String;
      Status         : out Launch_Status);

   --  Reap completed launcher children without blocking the caller. The main
   --  loop calls this once per frame; it is a no-op on platforms whose native
   --  launcher does not create process children owned by this application.
   procedure Poll;

private
   procedure Dispatch_URI
     (Preferred_Program : String;
      Fallback_Program  : String;
      URI               : String;
      Status            : out Launch_Status;
      Start             : not null access procedure
        (Program : String;
         URI     : String;
         Status  : out Launch_Status));

   procedure Launch_Program
     (Program : String;
      URI     : String;
      Status  : out Launch_Status);
   function Child_Tracking_Available return Boolean;
   function Pending_Launch_Count return Natural;
end Terminal.App.Platform_Launcher;
