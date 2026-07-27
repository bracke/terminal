package body Terminal.App.Tabs is
   function Trim_Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trim_Image;

   function Default_Label (Index : Tab_Index) return Tab_Label is
      Prefix : constant String := "Tab ";
      Number : constant String := Trim_Image (Index);
      Result : Tab_Label;

      procedure Append_String (Text : String) is
      begin
         for Ch of Text loop
            exit when Result.Length = Max_Tab_Label_Length;
            Result.Length := Result.Length + 1;
            Result.Text (Result.Length) := Ch;
         end loop;
      end Append_String;
   begin
      Append_String (Prefix);
      Append_String (Number);
      return Result;
   end Default_Label;

   procedure Initialize (State : out Tab_State) is
   begin
      State :=
        (Current_Count => 1,
         Active_Index  => 1,
         Labels        => (others => <>));
      State.Labels (1) := Default_Label (1);
   end Initialize;

   procedure Apply
     (State  : in out Tab_State;
      Command : Tab_Command;
      Status  : out Tab_Status)
   is
   begin
      case Command is
         when No_Command =>
            Status := Ok;
         when New_Tab =>
            if State.Current_Count = Max_Tabs then
               Status := At_Capacity;
            else
               State.Current_Count := State.Current_Count + 1;
               State.Active_Index := State.Current_Count;
               State.Labels (State.Active_Index) :=
                 Default_Label (State.Active_Index);
               Status := Ok;
            end if;
         when Close_Tab =>
            if State.Current_Count <= 1 then
               Status := Last_Tab;
            else
               if State.Active_Index < State.Current_Count then
                  for I in State.Active_Index .. State.Current_Count - 1 loop
                     State.Labels (I) := State.Labels (I + 1);
                  end loop;
               end if;
               State.Labels (State.Current_Count) := (others => <>);
               State.Current_Count := State.Current_Count - 1;
               if State.Active_Index > State.Current_Count then
                  State.Active_Index := State.Current_Count;
               end if;
               Status := Ok;
            end if;
         when Next_Tab =>
            if State.Active_Index = State.Current_Count then
               State.Active_Index := 1;
            else
               State.Active_Index := State.Active_Index + 1;
            end if;
            Status := Ok;
         when Previous_Tab =>
            if State.Active_Index = 1 then
               State.Active_Index := Positive (State.Current_Count);
            else
               State.Active_Index := State.Active_Index - 1;
            end if;
            Status := Ok;
      end case;
   end Apply;

   procedure Activate
     (State  : in out Tab_State;
      Index  : Tab_Index;
      Status : out Tab_Status)
   is
   begin
      if Index > State.Current_Count then
         Status := Invalid_Index;
      else
         State.Active_Index := Index;
         Status := Ok;
      end if;
   end Activate;

   procedure Set_Label
     (State : in out Tab_State;
      Index : Tab_Index;
      Text  : String;
      Status : out Tab_Status)
   is
      New_Label : Tab_Label;
   begin
      if Index > State.Current_Count then
         Status := Invalid_Index;
         return;
      end if;

      if Text'Length = 0 then
         State.Labels (Index) := Default_Label (Index);
      else
         for Ch of Text loop
            exit when New_Label.Length = Max_Tab_Label_Length;
            New_Label.Length := New_Label.Length + 1;
            New_Label.Text (New_Label.Length) := Ch;
         end loop;
         State.Labels (Index) := New_Label;
      end if;

      Status := Ok;
   end Set_Label;

   procedure Activate_At
     (State  : in out Tab_State;
      Layout : Tab_Layout;
      Col    : Positive;
      Status : out Tab_Status)
   is
      Hit : constant Tab_Count := Tab_At (Layout, Col);
   begin
      if Hit = 0 then
         Status := Invalid_Index;
      else
         Activate (State, Positive (Hit), Status);
      end if;
   end Activate_At;

   procedure Close_At
     (State  : in out Tab_State;
      Layout : Tab_Layout;
      Col    : Positive;
      Status : out Tab_Status)
   is
      Hit : constant Tab_Count := Tab_At (Layout, Col);
   begin
      if Hit = 0 then
         Status := Invalid_Index;
      else
         Activate (State, Positive (Hit), Status);
         if Status = Ok then
            Apply (State, Close_Tab, Status);
         end if;
      end if;
   end Close_At;

   function Count (State : Tab_State) return Tab_Count is
     (State.Current_Count);

   function Active (State : Tab_State) return Tab_Index is
     (State.Active_Index);

   function Snapshot (State : Tab_State) return Tab_Snapshot is
     ((Count  => State.Current_Count,
       Active => State.Active_Index,
       Labels => State.Labels));

   function Label
     (State : Tab_State;
      Index : Tab_Index) return Tab_Label is
   begin
      if Index > State.Current_Count then
         return (others => <>);
      else
         return State.Labels (Index);
      end if;
   end Label;

   function Label_Text (Label : Tab_Label) return String is
   begin
      if Label.Length = 0 then
         return "";
      else
         return Label.Text (1 .. Label.Length);
      end if;
   end Label_Text;

   function Fitted_Label
     (Label : Tab_Label;
      Width : Natural) return String
   is
      Text : constant String := Label_Text (Label);
   begin
      if Width = 0 then
         return "";
      elsif Text'Length <= Width then
         return Text;
      elsif Width <= 3 then
         return Text (Text'First .. Text'First + Width - 1);
      else
         return Text (Text'First .. Text'First + Width - 4) & "...";
      end if;
   end Fitted_Label;

   function Layout
     (State : Tab_State;
      Cols  : Positive) return Tab_Layout
   is
      Result : Tab_Layout := (Count => State.Current_Count, Rects => (others => <>));
      Count  : constant Positive := Positive (State.Current_Count);
      Base   : constant Natural := Cols / Count;
      Extra  : constant Natural := Cols mod Count;
      Cursor : Positive := 1;
   begin
      for I in 1 .. State.Current_Count loop
         declare
            Width : constant Natural :=
              Natural'Max
                (Min_Tab_Width,
                 Base + (if Natural (I) <= Extra then 1 else 0));
         begin
            Result.Rects (I) :=
              (Col    => Cursor,
               Width  => Width,
               Active => I = State.Active_Index);
            Cursor := Cursor + Width;
         end;
      end loop;

      return Result;
   end Layout;

   function Tab_At
     (Layout : Tab_Layout;
      Col    : Positive) return Tab_Count
   is
   begin
      for I in 1 .. Layout.Count loop
         declare
            Rect : constant Tab_Rect := Layout.Rects (I);
         begin
            if Rect.Width > 0
              and then Col >= Rect.Col
              and then Col < Rect.Col + Rect.Width
            then
               return I;
            end if;
         end;
      end loop;

      return 0;
   end Tab_At;

   function Status_Label (State : Tab_State) return String is
   begin
      if State.Current_Count <= 1 then
         return "Single live session; tab model ready";
      else
         return "Tab model active; multi-session rendering postponed";
      end if;
   end Status_Label;

   function Title_Suffix (State : Tab_State) return String is
   begin
      if State.Current_Count <= 1 then
         return "";
      else
         return
           " ["
           & Trim_Image (State.Active_Index)
           & "/"
           & Trim_Image (State.Current_Count)
           & "]";
      end if;
   end Title_Suffix;
end Terminal.App.Tabs;
