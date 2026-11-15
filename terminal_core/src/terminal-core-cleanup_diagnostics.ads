with Ada.Exceptions;

private package Terminal.Core.Cleanup_Diagnostics is
   procedure Note_Snapshot_Finalizer_Failure
     (Occurrence : Ada.Exceptions.Exception_Occurrence);
   function Snapshot_Finalizer_Diagnostics
     return Snapshot_Finalizer_Diagnostic;
   procedure Reset_Snapshot_Finalizer_Diagnostics;
end Terminal.Core.Cleanup_Diagnostics;
