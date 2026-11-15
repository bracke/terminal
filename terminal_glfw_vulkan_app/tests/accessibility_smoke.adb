with AUnit.Assertions;
with A11ykit.Provider;
with GLFW_Vulkan.Windows;
with Terminal.App.Accessibility;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Accessibility_Smoke is
   use AUnit.Assertions;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   Core : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed : Terminal.Core.Feed_Status;
   Window : GLFW_Vulkan.Windows.Window;
   Accessibility : Terminal.App.Accessibility.State;
   Data : Terminal.Common.Bytes.Byte_Array (1 .. 5);
   Hello : constant String := "hello";
begin
   for I in Data'Range loop
      Data (I) := Terminal.Common.Bytes.Byte (Character'Pos (Hello (I)));
   end loop;
   Terminal.Core.Initialize (Core, 2, 8, 10, Init);
   Assert (Init = Terminal.Core.Ok, "accessibility core initializes");
   Terminal.Core.Feed (Core, Data, Feed);
   Assert (Feed = Terminal.Core.Ok, "accessibility fixture feeds");
   declare
      Snapshot : Terminal.Core.Render_Snapshot := Terminal.Core.Snapshot (Core);
   begin
      Terminal.App.Accessibility.Initialize (Accessibility, Window);
      Terminal.App.Accessibility.Set_Focused (Accessibility, True);
      Terminal.App.Accessibility.Publish
        (Accessibility, Snapshot, 640, 480, 8, 16, 4,
         "Accessibility smoke", "READY");
      Terminal.App.Accessibility.Service (Accessibility);
      Assert
        (Terminal.App.Accessibility.Status_Label (Accessibility) /=
           "a11y=stopped"
         and then A11ykit.Provider.Last_Published_Event_Count > 0,
         "accessibility provider publishes validated semantic events");
      Terminal.App.Accessibility.Finalize (Accessibility);
      Terminal.Core.Release (Snapshot);
   end;
end Accessibility_Smoke;
