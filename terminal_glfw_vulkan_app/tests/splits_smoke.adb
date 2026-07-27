with AUnit.Assertions;

with GLFW_Vulkan.Input;
with Terminal.App.Input_Map;
with Terminal.App.Splits;

procedure Splits_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Splits.Split_Command;
   use type Terminal.App.Splits.Pane_Count;
   use type Terminal.App.Splits.Pane_Rect;
   use type Terminal.App.Splits.Pane_Index;
   use type Terminal.App.Splits.Split_Orientation;
   use type Terminal.App.Splits.Split_Status;

   package GI renames GLFW_Vulkan.Input;
   package Splits renames Terminal.App.Splits;

   State  : Splits.Split_State;
   Status : Splits.Split_Status;

   function Key_Event
     (Key     : GI.Key;
      Action  : GI.Key_Action := GI.Press;
      Shift   : Boolean := False;
      Control : Boolean := False;
      Alt     : Boolean := False;
      Super   : Boolean := False) return GI.Key_Event
   is
   begin
      return
        (Key       => Key,
         Raw_Key   => 0,
         Scancode  => 0,
         Action    => Action,
         Modifiers =>
           (Shift => Shift, Control => Control, Alt => Alt, Super => Super));
   end Key_Event;
begin
   Splits.Initialize (State);
   Assert (Splits.Count (State) = 1, "initial pane count");
   Assert (Splits.Active (State) = 1, "initial active pane");
   Assert (Splits.Title_Suffix (State) = "", "single pane suffix");
   Assert
     (Splits.Status_Label (State) = "Single live pane; split model ready",
      "single split status label");
   Assert
     (Splits.Status_Label (State)'Length <= Splits.Max_Status_Label_Length,
      "split status label should be bounded");
   Assert (Splits.Pane_Label (1) = "Pane 1", "pane label");
   Assert (Splits.Fitted_Label (1, 6) = "Pane 1", "pane fitted label exact");
   Assert
     (Splits.Fitted_Label (1, 5) = "Pa...",
      "pane fitted label clipped with marker");
   Assert (Splits.Fitted_Label (1, 2) = "Pa", "pane fitted label tiny");
   Assert (Splits.Fitted_Label (1, 0) = "", "pane fitted label zero width");
   declare
      Info : constant Splits.Split_Snapshot := Splits.Snapshot (State);
   begin
      Assert (Info.Count = 1, "initial split snapshot count");
      Assert (Info.Active = 1, "initial split snapshot active");
      Assert
        (Info.Orientation = Splits.Horizontal,
         "initial split snapshot orientation");
   end;

   Splits.Apply (State, Splits.Split_Horizontal, Status);
   Assert (Status = Splits.Ok, "horizontal split status");
   Assert (Splits.Count (State) = 2, "horizontal split count");
   Assert (Splits.Active (State) = 2, "new pane should become active");
   Assert (Splits.Title_Suffix (State) = " pane 2/2", "split title suffix");
   Assert
     (Splits.Status_Label (State) =
      "Split model active; split-pane rendering postponed",
      "active split model status label");
   declare
      Info : constant Splits.Split_Snapshot := Splits.Snapshot (State);
   begin
      Assert (Info.Count = 2, "horizontal split snapshot count");
      Assert (Info.Active = 2, "horizontal split snapshot active");
      Assert
        (Info.Orientation = Splits.Horizontal,
         "horizontal split snapshot orientation");
   end;
   declare
      Layout : constant Splits.Pane_Layout := Splits.Layout (State, 9, 20);
   begin
      Assert (Layout.Count = 2, "horizontal layout count");
      Assert
        (Layout.Rects (1) =
         (Row => 1, Col => 1, Rows => 5, Cols => 20, Active => False),
         "horizontal first pane rect");
      Assert
        (Layout.Rects (2) =
         (Row => 6, Col => 1, Rows => 4, Cols => 20, Active => True),
         "horizontal second pane rect");
      Assert (Splits.Pane_At (Layout, 1, 20) = 1, "horizontal pane hit first");
      Assert (Splits.Pane_At (Layout, 6, 1) = 2, "horizontal pane hit second");
      Assert (Splits.Pane_At (Layout, 10, 1) = 0, "horizontal pane miss");
      Splits.Activate_At (State, Layout, 1, 20, Status);
      Assert (Status = Splits.Ok, "activate first pane by cell status");
      Assert (Splits.Active (State) = 1, "activate first pane by cell");
      Splits.Activate_At (State, Layout, 6, 1, Status);
      Assert (Status = Splits.Ok, "activate second pane by cell status");
      Assert (Splits.Active (State) = 2, "activate second pane by cell");
      Splits.Activate_At (State, Layout, 10, 1, Status);
      Assert (Status = Splits.Invalid_Index, "activate pane miss status");
      Assert (Splits.Active (State) = 2, "activate pane miss preserves active");
      Splits.Close_At (State, Layout, 1, 20, Status);
      Assert (Status = Splits.Ok, "close pane by cell status");
      Assert (Splits.Count (State) = 1, "close pane by cell count");
      Assert (Splits.Active (State) = 1, "close pane by cell active");
      Splits.Close_At (State, Layout, 10, 1, Status);
      Assert (Status = Splits.Invalid_Index, "close pane miss status");
      Assert (Splits.Count (State) = 1, "close pane miss preserves count");
   end;

   Splits.Apply (State, Splits.Split_Horizontal, Status);
   Assert (Status = Splits.Ok, "restore split status");
   Splits.Apply (State, Splits.Next_Pane, Status);
   Assert (Status = Splits.Ok, "next pane status");
   Assert (Splits.Active (State) = 1, "next pane should wrap");

   Splits.Apply (State, Splits.Split_Vertical, Status);
   Assert (Status = Splits.Ok, "vertical split status");
   Assert (Splits.Count (State) = 3, "vertical split count");
   Assert (Splits.Active (State) = 3, "vertical split active pane");

   Splits.Activate (State, 1, Status);
   Assert (Status = Splits.Ok, "activate valid pane");
   Splits.Activate (State, 4, Status);
   Assert (Status = Splits.Invalid_Index, "activate invalid pane");
   Assert (Splits.Active (State) = 1, "invalid activate preserves active pane");

   Splits.Apply (State, Splits.Close_Pane, Status);
   Assert (Status = Splits.Ok, "close pane status");
   Assert (Splits.Count (State) = 2, "close pane count");

   Splits.Apply (State, Splits.Close_Pane, Status);
   Assert (Status = Splits.Ok, "close second pane status");
   Splits.Apply (State, Splits.Close_Pane, Status);
   Assert (Status = Splits.Last_Pane, "closing last pane should be rejected");

   for I in 2 .. Splits.Max_Panes loop
      Splits.Apply (State, Splits.Split_Horizontal, Status);
      Assert (Status = Splits.Ok, "fill pane" & Natural'Image (I));
   end loop;
   Splits.Apply (State, Splits.Split_Vertical, Status);
   Assert (Status = Splits.At_Capacity, "pane capacity should be bounded");

   Assert
     (Terminal.App.Input_Map.Split_Command
        (Key_Event (GI.H, Control => True, Shift => True))
      = Splits.Split_Horizontal,
      "ctrl-shift-h shortcut");
   Assert
     (Terminal.App.Input_Map.Split_Command
        (Key_Event (GI.V, Control => True, Shift => True))
      = Splits.Split_Vertical,
      "ctrl-shift-v shortcut");
   Assert
     (Terminal.App.Input_Map.Split_Command
        (Key_Event (GI.X, Control => True, Shift => True))
      = Splits.Close_Pane,
      "ctrl-shift-x shortcut");
   Assert
     (Terminal.App.Input_Map.Split_Command
        (Key_Event (GI.L, Control => True, Shift => True))
      = Splits.Next_Pane,
      "ctrl-shift-l shortcut");
   Assert
     (Terminal.App.Input_Map.Split_Command
        (Key_Event (GI.H, Control => True)) = Splits.No_Command,
      "plain ctrl-h remains terminal input");

   Splits.Initialize (State);
   Splits.Apply (State, Splits.Split_Vertical, Status);
   Assert (Status = Splits.Ok, "vertical layout split status");
   Splits.Apply (State, Splits.Split_Vertical, Status);
   Assert (Status = Splits.Ok, "vertical layout second split status");
   declare
      Layout : constant Splits.Pane_Layout := Splits.Layout (State, 8, 10);
   begin
      Assert (Layout.Count = 3, "vertical layout count");
      Assert
        (Layout.Rects (1) =
         (Row => 1, Col => 1, Rows => 8, Cols => 4, Active => False),
         "vertical first pane rect");
      Assert
        (Layout.Rects (2) =
         (Row => 1, Col => 5, Rows => 8, Cols => 3, Active => False),
         "vertical second pane rect");
      Assert
        (Layout.Rects (3) =
         (Row => 1, Col => 8, Rows => 8, Cols => 3, Active => True),
         "vertical third pane rect");
      Assert (Splits.Pane_At (Layout, 8, 4) = 1, "vertical pane hit first");
      Assert (Splits.Pane_At (Layout, 1, 5) = 2, "vertical pane hit second");
      Assert (Splits.Pane_At (Layout, 3, 10) = 3, "vertical pane hit third");
      Assert (Splits.Pane_At (Layout, 1, 11) = 0, "vertical pane miss");
      Splits.Activate_At (State, Layout, 3, 10, Status);
      Assert (Status = Splits.Ok, "activate vertical pane by cell status");
      Assert (Splits.Active (State) = 3, "activate vertical pane by cell");
      Splits.Close_At (State, Layout, 1, 5, Status);
      Assert (Status = Splits.Ok, "close vertical pane by cell status");
      Assert (Splits.Count (State) = 2, "close vertical pane by cell count");
      Assert (Splits.Active (State) = 2, "close vertical pane by cell active");
   end;
end Splits_Smoke;
