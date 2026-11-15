with Ada.Unchecked_Deallocation;

package body Terminal.Core.Hyperlink_Store is
   Sweep_Interval : constant Positive := 1_024;

   procedure Free is new Ada.Unchecked_Deallocation
     (Stored_Hyperlink, Stored_Hyperlink_Access);

   procedure Mark (Item : Stored_Hyperlink_Access) is
   begin
      if Item /= null then
         Item.Marked := True;
      end if;
   end Mark;

   procedure Mark (Cells : Stored_Cell_Array_Access) is
   begin
      if Cells /= null then
         for Cell of Cells.all loop
            Mark (Cell.Link);
         end loop;
      end if;
   end Mark;

   procedure Mark_Scrollback
     (Cells         : Stored_Cell_Array_Access;
      Rows          : Natural;
      Head          : Natural;
      Capacity_Rows : Natural;
      Cols          : Positive) is
   begin
      if Cells = null or else Rows = 0 then
         return;
      elsif Capacity_Rows = 0 or else Rows > Capacity_Rows then
         raise Program_Error with "invalid scrollback hyperlink roots";
      end if;
      for Row in 1 .. Rows loop
         declare
            Physical_Row : constant Natural :=
              (Head + Row - 1) mod Capacity_Rows;
         begin
            for Col in 1 .. Cols loop
               Mark (Cells (Physical_Row * Cols + Col).Link);
            end loop;
         end;
      end loop;
   end Mark_Scrollback;

   procedure Sweep
     (State      : in out Hyperlink_Runtime_State;
      Primary    : Stored_Cell_Array_Access;
      Alternate  : Stored_Cell_Array_Access;
      Scrollback : Scrollback_Runtime_State;
      Cols       : Positive)
   is
      Item     : Stored_Hyperlink_Access := State.Head;
   begin
      Mark (State.Current);
      Mark (Primary);
      Mark (Alternate);
      Mark_Scrollback
        (Scrollback.Cells,
         Scrollback.Rows,
         Scrollback.Head,
         Scrollback.Capacity_Rows,
         Cols);

      while Item /= null loop
         declare
            Following : constant Stored_Hyperlink_Access := Item.Next;
         begin
            if Item.Marked then
               Item.Marked := False;
            else
               State.Index.Delete (Item);
               if Item.Previous = null then
                  State.Head := Following;
               else
                  Item.Previous.Next := Following;
               end if;
               if Following /= null then
                  Following.Previous := Item.Previous;
               end if;
               Free (Item);
               State.Count := State.Count - 1;
            end if;
            Item := Following;
         end;
      end loop;

      State.Next_Sweep :=
        (if State.Count > Natural'Last - Sweep_Interval
         then Natural'Last
         else State.Count + Sweep_Interval);
   end Sweep;

   function Intern_Value
     (State : in out Hyperlink_Runtime_State;
      Value : Hyperlink) return Stored_Hyperlink_Access
   is
      Item : Stored_Hyperlink_Access := null;
   begin
      if not Value.Active then
         return null;
      elsif State.Count = Natural'Last then
         raise Storage_Error with "hyperlink store exhausted";
      end if;
      if State.Lookup = null then
         State.Lookup := new Stored_Hyperlink'
           (Value  => Value,
            Next   => null,
            Previous => null,
            Marked => False,
            Snapshot_References => 0);
      else
         State.Lookup.Value := Value;
      end if;
      declare
         Position : constant Stored_Hyperlink_Sets.Cursor :=
           State.Index.Find (State.Lookup);
      begin
         if Stored_Hyperlink_Sets.Has_Element (Position) then
            return Stored_Hyperlink_Sets.Element (Position);
         end if;
      end;
      Item := new Stored_Hyperlink'
        (Value  => Value,
         Next   => null,
         Previous => null,
         Marked => False,
         Snapshot_References => 0);
      begin
         State.Index.Insert (Item);
      exception
         when others =>
            Free (Item);
            raise;
      end;
      Item.Next := State.Head;
      if State.Head /= null then
         State.Head.Previous := Item;
      end if;
      State.Head := Item;
      State.Count := State.Count + 1;
      return Item;
   end Intern_Value;

   function Intern
     (State      : in out Hyperlink_Runtime_State;
      Primary    : Stored_Cell_Array_Access;
      Alternate  : Stored_Cell_Array_Access;
      Scrollback : Scrollback_Runtime_State;
      Cols       : Positive;
      Value      : Hyperlink) return Stored_Hyperlink_Access
   is
   begin
      if Value.Active and then State.Count >= State.Next_Sweep then
         Sweep (State, Primary, Alternate, Scrollback, Cols);
      end if;
      return Intern_Value (State, Value);
   end Intern;

   function Intern_Snapshot
     (State : in out Hyperlink_Runtime_State;
      Value : Hyperlink) return Stored_Hyperlink_Access
   is
      Item : Stored_Hyperlink_Access := Intern_Value (State, Value);
   begin
      if Item /= null then
         if Item.Snapshot_References = Natural'Last then
            raise Storage_Error with "snapshot hyperlink reference count exhausted";
         end if;
         Item.Snapshot_References := Item.Snapshot_References + 1;
      end if;
      return Item;
   end Intern_Snapshot;

   procedure Release_Snapshot
     (State : in out Hyperlink_Runtime_State;
      Item  : in out Stored_Hyperlink_Access)
   is
      Following : Stored_Hyperlink_Access;
   begin
      if Item = null then
         return;
      elsif Item.Snapshot_References = 0 then
         raise Program_Error with "snapshot hyperlink reference count underflow";
      end if;
      Item.Snapshot_References := Item.Snapshot_References - 1;
      if Item.Snapshot_References = 0 then
         Following := Item.Next;
         State.Index.Delete (Item);
         if Item.Previous = null then
            State.Head := Following;
         else
            Item.Previous.Next := Following;
         end if;
         if Following /= null then
            Following.Previous := Item.Previous;
         end if;
         Free (Item);
         State.Count := State.Count - 1;
      else
         Item := null;
      end if;
   end Release_Snapshot;

   procedure Release_All (State : in out Hyperlink_Runtime_State) is
   begin
      State.Index.Clear;
      while State.Head /= null loop
         declare
            Item : Stored_Hyperlink_Access := State.Head;
         begin
            State.Head := Item.Next;
            Free (Item);
         end;
      end loop;
      State.Current := null;
      if State.Lookup /= null then
         Free (State.Lookup);
      end if;
      State.Count := 0;
      State.Next_Sweep := Sweep_Interval;
   end Release_All;
end Terminal.Core.Hyperlink_Store;
