with AUnit.Assertions;

with GLFW_Vulkan.Input;
with Terminal.App.Input_Map;
with Terminal.App.Tabs;

procedure Tabs_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Tabs.Tab_Command;
   use type Terminal.App.Tabs.Tab_Label;
   use type Terminal.App.Tabs.Tab_Rect;
   use type Terminal.App.Tabs.Tab_Status;

   package GI renames GLFW_Vulkan.Input;
   package Tabs renames Terminal.App.Tabs;

   State  : Tabs.Tab_State;
   Status : Tabs.Tab_Status;

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
   Tabs.Initialize (State);
   Assert (Tabs.Count (State) = 1, "initial tab count");
   Assert (Tabs.Active (State) = 1, "initial active tab");
   Assert (Tabs.Title_Suffix (State) = "", "single tab suffix");
   Assert
     (Tabs.Status_Label (State) = "Single live session; tab model ready",
      "single tab status label");
   Assert
     (Tabs.Status_Label (State)'Length <= Tabs.Max_Status_Label_Length,
      "tab status label should be bounded");
   declare
      Info  : constant Tabs.Tab_Snapshot := Tabs.Snapshot (State);
      Label : constant Tabs.Tab_Label := Tabs.Label (State, 1);
   begin
      Assert (Info.Count = 1, "initial tab snapshot count");
      Assert (Info.Active = 1, "initial tab snapshot active");
      Assert (Info.Labels (1) = Label, "initial tab snapshot label");
      Assert (Label.Length = 5, "initial tab label length");
      Assert (Label.Text (1 .. Label.Length) = "Tab 1", "initial tab label");
      Assert
        (Tabs.Label_Text (Label) = "Tab 1",
         "initial tab label text");
      Assert
        (Tabs.Fitted_Label (Label, 5) = "Tab 1",
         "fitted tab label exact width");
      Assert
        (Tabs.Fitted_Label (Label, 4) = "T...",
         "fitted tab label clipped with marker");
      Assert
        (Tabs.Fitted_Label (Label, 2) = "Ta",
         "fitted tab label tiny width");
      Assert
        (Tabs.Fitted_Label (Label, 0) = "",
         "fitted tab label zero width");
   end;

   Tabs.Apply (State, Tabs.New_Tab, Status);
   Assert (Status = Tabs.Ok, "new tab status");
   Assert (Tabs.Count (State) = 2, "new tab count");
   Assert (Tabs.Active (State) = 2, "new tab should become active");
   Assert (Tabs.Title_Suffix (State) = " [2/2]", "new tab title suffix");
   Assert
     (Tabs.Status_Label (State) =
      "Tab model active; multi-session rendering postponed",
      "active tab model status label");
   declare
      Info  : constant Tabs.Tab_Snapshot := Tabs.Snapshot (State);
      Label : constant Tabs.Tab_Label := Tabs.Label (State, 2);
   begin
      Assert (Info.Count = 2, "new tab snapshot count");
      Assert (Info.Active = 2, "new tab snapshot active");
      Assert (Info.Labels (2) = Label, "new tab snapshot label");
      Assert (Label.Text (1 .. Label.Length) = "Tab 2", "new tab label");
   end;
   Tabs.Set_Label (State, 2, "shell", Status);
   Assert (Status = Tabs.Ok, "set tab label status");
   declare
      Label : constant Tabs.Tab_Label := Tabs.Label (State, 2);
   begin
      Assert (Label.Length = 5, "set tab label length");
      Assert (Label.Text (1 .. Label.Length) = "shell", "set tab label");
      Assert (Tabs.Label_Text (Label) = "shell", "set tab label text");
   end;
   Tabs.Set_Label (State, 2, "", Status);
   Assert (Status = Tabs.Ok, "reset tab label status");
   declare
      Label : constant Tabs.Tab_Label := Tabs.Label (State, 2);
   begin
      Assert (Label.Text (1 .. Label.Length) = "Tab 2", "reset tab label");
   end;
   Tabs.Set_Label (State, 3, "missing", Status);
   Assert (Status = Tabs.Invalid_Index, "set invalid tab label");

   Tabs.Apply (State, Tabs.Previous_Tab, Status);
   Assert (Status = Tabs.Ok, "previous tab status");
   Assert (Tabs.Active (State) = 1, "previous tab should wrap");
   Assert (Tabs.Title_Suffix (State) = " [1/2]", "previous tab title suffix");

   Tabs.Apply (State, Tabs.Next_Tab, Status);
   Assert (Status = Tabs.Ok, "next tab status");
   Assert (Tabs.Active (State) = 2, "next tab should wrap forward");
   declare
      Layout : constant Tabs.Tab_Layout := Tabs.Layout (State, 15);
   begin
      Assert (Layout.Count = 2, "two-tab layout count");
      Assert
        (Layout.Rects (1) = (Col => 1, Width => 8, Active => False),
         "two-tab first rect");
      Assert
        (Layout.Rects (2) = (Col => 9, Width => 7, Active => True),
         "two-tab second rect");
      Assert (Tabs.Tab_At (Layout, 1) = 1, "two-tab first hit");
      Assert (Tabs.Tab_At (Layout, 9) = 2, "two-tab second hit");
      Assert (Tabs.Tab_At (Layout, 16) = 0, "two-tab miss");
      Tabs.Activate_At (State, Layout, 1, Status);
      Assert (Status = Tabs.Ok, "activate first tab by column status");
      Assert (Tabs.Active (State) = 1, "activate first tab by column");
      Tabs.Activate_At (State, Layout, 9, Status);
      Assert (Status = Tabs.Ok, "activate second tab by column status");
      Assert (Tabs.Active (State) = 2, "activate second tab by column");
      Tabs.Activate_At (State, Layout, 16, Status);
      Assert (Status = Tabs.Invalid_Index, "activate tab miss status");
      Assert (Tabs.Active (State) = 2, "activate tab miss preserves active");
      Tabs.Close_At (State, Layout, 1, Status);
      Assert (Status = Tabs.Ok, "close tab by column status");
      Assert (Tabs.Count (State) = 1, "close tab by column count");
      Assert (Tabs.Active (State) = 1, "close tab by column active");
      Tabs.Close_At (State, Layout, 16, Status);
      Assert (Status = Tabs.Invalid_Index, "close tab miss status");
      Assert (Tabs.Count (State) = 1, "close tab miss preserves count");
   end;

   Tabs.Apply (State, Tabs.New_Tab, Status);
   Assert (Status = Tabs.Ok, "restore second tab status");
   Tabs.Activate (State, 1, Status);
   Assert (Status = Tabs.Ok, "select valid tab");
   Assert (Tabs.Active (State) = 1, "selected active tab");

   Tabs.Activate (State, 3, Status);
   Assert (Status = Tabs.Invalid_Index, "select invalid tab");
   Assert (Tabs.Active (State) = 1, "invalid select should preserve active tab");

   Tabs.Apply (State, Tabs.Close_Tab, Status);
   Assert (Status = Tabs.Ok, "close tab status");
   Assert (Tabs.Count (State) = 1, "close tab count");
   Assert (Tabs.Active (State) = 1, "close tab active");
   declare
      Label : constant Tabs.Tab_Label := Tabs.Label (State, 2);
   begin
      Assert (Label.Length = 0, "closed tab label should clear");
   end;

   Tabs.Apply (State, Tabs.Close_Tab, Status);
   Assert (Status = Tabs.Last_Tab, "closing last tab should be rejected");

   for I in 2 .. Tabs.Max_Tabs loop
      Tabs.Apply (State, Tabs.New_Tab, Status);
      Assert (Status = Tabs.Ok, "fill tab" & Natural'Image (I));
   end loop;
   Tabs.Apply (State, Tabs.New_Tab, Status);
   Assert (Status = Tabs.At_Capacity, "tab capacity should be bounded");
   Assert (Tabs.Count (State) = Tabs.Max_Tabs, "capacity count");
   declare
      Layout : constant Tabs.Tab_Layout := Tabs.Layout (State, 10);
   begin
      Assert (Layout.Count = Tabs.Max_Tabs, "capacity layout count");
      Assert
        (Layout.Rects (1).Width = Tabs.Min_Tab_Width,
         "capacity layout minimum width");
      Assert
        (Tabs.Tab_At (Layout, Tabs.Min_Tab_Width * Tabs.Max_Tabs) =
         Tabs.Max_Tabs,
         "capacity layout last hit");
   end;

   Assert
     (Terminal.App.Input_Map.Tab_Command
        (Key_Event (GI.T, Control => True, Shift => True)) = Tabs.New_Tab,
      "ctrl-shift-t shortcut");
   Assert
     (Terminal.App.Input_Map.Tab_Command
        (Key_Event (GI.W, Control => True, Shift => True)) = Tabs.Close_Tab,
      "ctrl-shift-w shortcut");
   Assert
     (Terminal.App.Input_Map.Tab_Command
        (Key_Event (GI.Page_Down, Control => True)) = Tabs.Next_Tab,
      "ctrl-page-down shortcut");
   Assert
     (Terminal.App.Input_Map.Tab_Command
        (Key_Event (GI.Page_Up, Control => True)) = Tabs.Previous_Tab,
      "ctrl-page-up shortcut");
   Assert
     (Terminal.App.Input_Map.Tab_Command
        (Key_Event (GI.T, Control => True)) = Tabs.No_Command,
      "plain ctrl-t remains terminal input");
end Tabs_Smoke;
