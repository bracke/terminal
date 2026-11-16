package Terminal.App.Shell_Integration is
   function Native_Terminfo_Available return Boolean;

   --  Build the first interactive-shell command for a new session.  The
   --  command exports the per-window control socket, selects the native TERM
   --  only when its compiled entry is installed, and sources an integration
   --  script when one is available for the current shell.
   function Bootstrap
     (Enabled      : Boolean;
      Control_Path : String) return String;
end Terminal.App.Shell_Integration;
