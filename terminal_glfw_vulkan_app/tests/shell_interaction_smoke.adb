with AUnit.Assertions;
with GLFW_Vulkan.Input;
with Terminal.App.Key_Bindings;
with Terminal.App.Selection;
with Terminal.App.Shell_Blocks;
with Terminal.App.Text_Composition;
with Terminal.Common.Bytes;
with Terminal.Core;

procedure Shell_Interaction_Smoke is
   use AUnit.Assertions;
   use type Terminal.Core.Feed_Status;
   use type Terminal.Core.Initialize_Status;
   use type Terminal.App.Key_Bindings.Action;

   function Bytes (Text : String) return Terminal.Common.Bytes.Byte_Array is
      Result : Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end Bytes;

   Composition : Terminal.App.Text_Composition.State;
   Code_Point : Wide_Wide_Character;
   Valid : Boolean;
   Core : Terminal.Core.Terminal;
   Init : Terminal.Core.Initialize_Status;
   Feed : Terminal.Core.Feed_Status;
begin
   declare
      Bindings : constant Terminal.App.Key_Bindings.Binding_Set :=
        Terminal.App.Key_Bindings.Defaults;
   begin
      Assert
        (Terminal.App.Key_Bindings.Action_For
           (Bindings,
            (Key => GLFW_Vulkan.Input.R,
             Raw_Key => 0,
             Scancode => 0,
             Action => GLFW_Vulkan.Input.Press,
             Modifiers =>
               (Shift => True, Control => True, Alt => False, Super => False))) =
           Terminal.App.Key_Bindings.Rerun_Command_Block,
         "shell command block shortcuts are configurable actions");
   end;

   Terminal.App.Text_Composition.Begin_Composition (Composition);
   for Ch of String'("4e2d") loop
      Terminal.App.Text_Composition.Append (Composition, Ch);
   end loop;
   Assert
     (Terminal.App.Text_Composition.Status_Label (Composition) =
        "Compose U+4e2d_",
      "composition exposes bounded pre-edit text");
   Terminal.App.Text_Composition.Commit (Composition, Code_Point, Valid);
   Assert
     (Valid and then Wide_Wide_Character'Pos (Code_Point) = 16#4E2D#
      and then not Terminal.App.Text_Composition.Active (Composition),
      "composition commits a Unicode scalar");

   Terminal.App.Text_Composition.Begin_Composition (Composition);
   for Ch of String'("d800") loop
      Terminal.App.Text_Composition.Append (Composition, Ch);
   end loop;
   Terminal.App.Text_Composition.Commit (Composition, Code_Point, Valid);
   Assert (not Valid, "composition rejects surrogate values");

   Terminal.Core.Initialize (Core, 4, 20, 100, Init);
   Assert (Init = Terminal.Core.Ok, "shell block core initialize");
   Terminal.Core.Feed
     (Core,
      Bytes
        (ASCII.ESC & "]133;A" & ASCII.BEL & "$ "
         & ASCII.ESC & "]133;B" & ASCII.BEL & "echo ok" & ASCII.CR & ASCII.LF
         & ASCII.ESC & "]133;C" & ASCII.BEL & "ok" & ASCII.CR & ASCII.LF
         & ASCII.ESC & "]133;D;0;12" & ASCII.BEL),
      Feed);
   Assert (Feed = Terminal.Core.Ok, "shell block stream feed");
   declare
      Block : constant Terminal.Core.Shell_Command_Block :=
        Terminal.App.Shell_Blocks.Latest (Core);
      First, Last : Terminal.App.Selection.Cell_Position;
      Visible : Boolean;
   begin
      Assert
        (Terminal.App.Shell_Blocks.Command_Text (Core, Block) = "echo ok",
         "shell block extracts rerunnable command text without prompt");
      Assert
        (Block.Has_Exit_Status and then Block.Exit_Status = 0
         and then Block.Has_Duration and then Block.Duration_Milliseconds = 12,
         "shell block retains result and duration");
      Terminal.App.Shell_Blocks.Visible_Range
        (Core, Block, 0, First, Last, Visible);
      Assert
        (Visible and then First.Row = 1 and then First.Col = 1
         and then Last.Row = 3,
         "shell block maps to a visible selectable range");
      Terminal.App.Shell_Blocks.Visible_Range
        (Core, Block, Natural'Last, First, Last, Visible);
      Assert
        (Visible,
         "shell block clamps a stale scroll offset instead of underflowing");
   end;

   Terminal.Core.Finalize (Core);
end Shell_Interaction_Smoke;
