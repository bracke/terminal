with Ada.Exceptions;

package body Terminal.Core.Cleanup_Diagnostics is
   protected Counter is
      procedure Note (Exception_Name : String);
      function Value return Snapshot_Finalizer_Diagnostic;
      procedure Reset;
   private
      Diagnostic : Snapshot_Finalizer_Diagnostic;
   end Counter;

   protected body Counter is
      procedure Note (Exception_Name : String) is
         Length : constant Natural :=
           Natural'Min
             (Exception_Name'Length, Max_Snapshot_Cleanup_Detail_Length);
      begin
         if Diagnostic.Count < Natural'Last then
            Diagnostic.Count := Diagnostic.Count + 1;
         end if;
         Diagnostic.Exception_Length := Length;
         Diagnostic.Exception_Name := (others => ' ');
         if Length > 0 then
            Diagnostic.Exception_Name (1 .. Length) :=
              Exception_Name
                (Exception_Name'First .. Exception_Name'First + Length - 1);
         end if;
      end Note;

      function Value return Snapshot_Finalizer_Diagnostic is (Diagnostic);

      procedure Reset is
      begin
         Diagnostic := (others => <>);
      end Reset;
   end Counter;

   procedure Note_Snapshot_Finalizer_Failure
     (Occurrence : Ada.Exceptions.Exception_Occurrence) is
   begin
      Counter.Note (Ada.Exceptions.Exception_Name (Occurrence));
   end Note_Snapshot_Finalizer_Failure;

   function Snapshot_Finalizer_Diagnostics
     return Snapshot_Finalizer_Diagnostic is
     (Counter.Value);

   procedure Reset_Snapshot_Finalizer_Diagnostics is
   begin
      Counter.Reset;
   end Reset_Snapshot_Finalizer_Diagnostics;
end Terminal.Core.Cleanup_Diagnostics;
