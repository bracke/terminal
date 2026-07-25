with Terminal.Core;
with Terminal.App.Queues;

package Terminal.App.Diagnostics is
   type Snapshot is record
      Core          : Terminal.Core.Diagnostic_Snapshot;
      PTY_Overflows : Natural := 0;
      Input_Overflows : Natural := 0;
   end record;
end Terminal.App.Diagnostics;

