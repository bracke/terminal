package body Terminal.App.Sessions is
   use type Terminal.App.Splits.Split_Status;
   use type Terminal.App.Tabs.Tab_Status;

   function Trim_Image (Value : Natural) return String is
      Text : constant String := Natural'Image (Value);
   begin
      return Text (Text'First + 1 .. Text'Last);
   end Trim_Image;

   procedure Initialize (Table : out Session_Table) is
   begin
      Table :=
        (Current_Count => 1,
         Active_Index  => 1,
         States        => (others => Unused));
      Table.States (1) := Live;
   end Initialize;

   procedure New_Session
     (Table  : in out Session_Table;
      Status : out Session_Status)
   is
   begin
      if Table.Current_Count = Max_Sessions then
         Status := At_Capacity;
      else
         Table.Current_Count := Table.Current_Count + 1;
         Table.Active_Index := Table.Current_Count;
         Table.States (Table.Active_Index) := Live;
         Status := Ok;
      end if;
   end New_Session;

   procedure Close_Active
     (Table  : in out Session_Table;
      Status : out Session_Status)
   is
   begin
      if Table.Current_Count <= 1 then
         Status := Last_Session;
         return;
      end if;

      Table.States (Table.Active_Index) := Closed;
      if Table.Active_Index < Table.Current_Count then
         for I in Table.Active_Index .. Table.Current_Count - 1 loop
            Table.States (I) := Table.States (I + 1);
         end loop;
      end if;

      Table.States (Table.Current_Count) := Unused;
      Table.Current_Count := Table.Current_Count - 1;
      if Table.Active_Index > Table.Current_Count then
         Table.Active_Index := Table.Current_Count;
      end if;
      Status := Ok;
   end Close_Active;

   procedure Activate
     (Table  : in out Session_Table;
      Index  : Session_Index;
      Status : out Session_Status)
   is
   begin
      if Index > Table.Current_Count or else Table.States (Index) /= Live then
         Status := Invalid_Index;
      else
         Table.Active_Index := Index;
         Status := Ok;
      end if;
   end Activate;

   procedure Activate_Tab
     (Table  : in out Session_Table;
      Tabs   : in out Terminal.App.Tabs.Tab_State;
      Index  : Terminal.App.Tabs.Tab_Index;
      Status : out Session_Status)
   is
      Tab_Status : Terminal.App.Tabs.Tab_Status;
      Next_Table : Session_Table := Table;
      Next_Tabs  : Terminal.App.Tabs.Tab_State := Tabs;
   begin
      Terminal.App.Tabs.Activate (Next_Tabs, Index, Tab_Status);
      if Tab_Status /= Terminal.App.Tabs.Ok then
         Status := Invalid_Index;
         return;
      end if;
      Activate (Next_Table, Session_Index (Index), Status);
      if Status = Ok then
         Table := Next_Table;
         Tabs := Next_Tabs;
      end if;
   end Activate_Tab;

   procedure Activate_Pane
     (Table  : in out Session_Table;
      Splits : in out Terminal.App.Splits.Split_State;
      Index  : Terminal.App.Splits.Pane_Index;
      Status : out Session_Status)
   is
      Split_Status : Terminal.App.Splits.Split_Status;
      Next_Table  : Session_Table := Table;
      Next_Splits : Terminal.App.Splits.Split_State := Splits;
   begin
      Terminal.App.Splits.Activate (Next_Splits, Index, Split_Status);
      if Split_Status /= Terminal.App.Splits.Ok then
         Status := Invalid_Index;
         return;
      end if;
      Activate (Next_Table, Session_Index (Index), Status);
      if Status = Ok then
         Table := Next_Table;
         Splits := Next_Splits;
      end if;
   end Activate_Pane;

   function Count (Table : Session_Table) return Session_Count is
     (Table.Current_Count);

   function Active (Table : Session_Table) return Session_Index is
     (Table.Active_Index);

   function Lifecycle
     (Table : Session_Table;
      Index : Session_Index) return Session_Lifecycle is
   begin
      if Index > Table.Current_Count then
         return Unused;
      else
         return Table.States (Index);
      end if;
   end Lifecycle;

   function Snapshot (Table : Session_Table) return Session_Snapshot is
     ((Count  => Table.Current_Count,
       Active => Table.Active_Index,
       States => Table.States));

   function Status_Label (Table : Session_Table) return String is
   begin
      if Table.Current_Count <= 1 then
         return "Single live session";
      else
         return
           "Live sessions="
           & Trim_Image (Table.Current_Count)
           & " active="
           & Trim_Image (Table.Active_Index);
      end if;
   end Status_Label;
end Terminal.App.Sessions;
