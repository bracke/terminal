with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Terminal.Common.Status;

package body Terminal.App.Command_Palette is
   use type Terminal.App.Key_Bindings.Action;
   function Label (Value : State; Index : Item_Index) return String is
     (Value.Labels (Index).Text (1 .. Value.Labels (Index).Length));

   procedure Refilter (Value : in out State) is
      Query : constant String :=
        Ada.Characters.Handling.To_Lower
          (Value.Query (1 .. Value.Query_Length));
   begin
      Value.Matches_Count := 0;
      for I in 1 .. Value.Item_Count loop
         if Query = ""
           or else Ada.Strings.Fixed.Index
             (Ada.Characters.Handling.To_Lower (Label (Value, I)), Query) > 0
         then
            Value.Matches_Count := Value.Matches_Count + 1;
            Value.Matches (Value.Matches_Count) := I;
         end if;
      end loop;
      Value.Current := 1;
   end Refilter;

   procedure Add
     (Value : in out State;
      Item  : Choice;
      Text  : String) is
      Count : constant Natural := Natural'Min (Text'Length, 64);
   begin
      if Value.Item_Count = Max_Items then return; end if;
      Value.Item_Count := Value.Item_Count + 1;
      Value.Items (Value.Item_Count) := Item;
      Value.Labels (Value.Item_Count).Length := Count;
      if Count > 0 then
         Value.Labels (Value.Item_Count).Text (1 .. Count) :=
           Text (Text'First .. Text'First + Count - 1);
      end if;
   end Add;

   procedure Enter
     (Value    : in out State;
      Profiles : Terminal.App.Session_Profiles.Registry) is
   begin
      Value := (others => <>);
      Value.Enabled := True;
      for Action in Terminal.App.Key_Bindings.Configurable_Action loop
         if Action /= Terminal.App.Key_Bindings.Command_Palette then
            Add
              (Value,
               (Kind => Action_Choice, Action => Action, Profile_Index => 0),
               Terminal.App.Key_Bindings.Action_Name (Action));
         end if;
      end loop;
      for I in 1 .. Terminal.App.Session_Profiles.Count (Profiles) loop
         Add
           (Value,
            (Kind => Profile_Choice,
             Action => Terminal.App.Key_Bindings.New_Tab,
             Profile_Index => I),
            "profile " & Terminal.App.Session_Profiles.Name
              (Terminal.App.Session_Profiles.Item (Profiles, I)));
      end loop;
      Refilter (Value);
   end Enter;

   procedure Leave (Value : in out State) is
   begin
      Value.Enabled := False;
      Value.Query_Length := 0;
      Value.Matches_Count := 0;
      Value.Current := 1;
   end Leave;

   procedure Append (Value : in out State; Ch : Character) is
   begin
      if Value.Enabled and then Value.Query_Length < Max_Query_Length
        and then Ch in ' ' .. '~'
      then
         Value.Query_Length := Value.Query_Length + 1;
         Value.Query (Value.Query_Length) := Ch;
         Refilter (Value);
      end if;
   end Append;

   procedure Backspace (Value : in out State) is
   begin
      if Value.Enabled and then Value.Query_Length > 0 then
         Value.Query_Length := Value.Query_Length - 1;
         Refilter (Value);
      end if;
   end Backspace;

   procedure Move (Value : in out State; Offset : Integer) is
      Zero : Integer;
   begin
      if not Value.Enabled or else Value.Matches_Count = 0 then return; end if;
      Zero := (Integer (Value.Current) - 1 + Offset)
        mod Integer (Value.Matches_Count);
      Value.Current := Item_Index (Zero + 1);
   end Move;

   function Active (Value : State) return Boolean is (Value.Enabled);
   function Match_Count (Value : State) return Natural is (Value.Matches_Count);

   function Selected (Value : State) return Choice is
     (if Value.Enabled and then Value.Matches_Count > 0
      then Value.Items (Value.Matches (Value.Current))
      else (others => <>));

   function Status_Label (Value : State) return String is
      Query : constant String := Value.Query (1 .. Value.Query_Length);
      Current_Label : constant String :=
        (if Value.Enabled and then Value.Matches_Count > 0
         then Label (Value, Value.Matches (Value.Current)) else "no matches");
      Text : constant String :=
        "PALETTE " & Query & " ["
        & Terminal.Common.Status.Trimmed_Natural
          (if Value.Matches_Count = 0 then 0 else Value.Current)
        & "/" & Terminal.Common.Status.Trimmed_Natural (Value.Matches_Count)
        & "] " & Current_Label;
   begin
      return Text (Text'First .. Natural'Min
        (Text'Last, Text'First + Max_Status_Length - 1));
   end Status_Label;
end Terminal.App.Command_Palette;
