package body Terminal.App.Placeholder_Index is
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Image_Placements.Conventional_Placement_Access;
   use type Terminal.App.Image_Placements.Virtual_Placement_Access;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.Core.Graphics_ID;

   function Mix
     (Left, Right : Interfaces.Unsigned_64) return Interfaces.Unsigned_64
   is (Left * 16#9E37_79B9_7F4A_7C15# + Right + 16#517C_C1B7_2722_0A95#);

   function Hash_Placement
     (Key : Placement_Key) return Ada.Containers.Hash_Type
   is
      Value : Interfaces.Unsigned_64 := Interfaces.Unsigned_64 (Key.Stream_ID);
   begin
      Value := Mix (Value, Interfaces.Unsigned_64 (Key.Screen_Generation));
      Value := Mix (Value, Interfaces.Unsigned_64 (Key.Image_ID));
      Value := Mix (Value, Interfaces.Unsigned_64 (Key.Placement_ID));
      if Key.Alternate_Screen then
         Value := Mix (Value, 1);
      end if;
      return Ada.Containers.Hash_Type'Mod (Value);
   end Hash_Placement;

   function Hash_Storage_Order
     (Key : Object_Key) return Ada.Containers.Hash_Type
   is
   begin
      return Ada.Containers.Hash_Type'Mod
        (Mix
           (Interfaces.Unsigned_64 (Key.Stream_ID),
            Key.Storage_Order));
   end Hash_Storage_Order;

   function Key_Of
     (Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID) return Placement_Key
   is
     (Stream_ID         => Stream_ID,
      Alternate_Screen  => Alternate_Screen,
      Screen_Generation => Screen_Generation,
      Image_ID          => Image_ID,
      Placement_ID      => Placement_ID);

   procedure Build
     (Item          : in out Index;
      Virtuals      : Terminal.App.Image_Placements.Virtual_Placement_Access;
      Conventionals :
        Terminal.App.Image_Placements.Conventional_Placement_Access;
      Images        : Terminal.App.Image_Store.Store)
   is
      Virtual : Terminal.App.Image_Placements.Virtual_Placement_Access :=
        Virtuals;
      Conventional :
        Terminal.App.Image_Placements.Conventional_Placement_Access :=
          Conventionals;
      Object : Terminal.App.Image_Store.Image_Object_Access :=
        Terminal.App.Image_Store.First (Images);
   begin
      Item.Placements.Clear;
      Item.Conventionals.Clear;
      Item.Objects.Clear;
      Item.Origins.Clear;
      Item.Origin_Epoch := 0;

      while Virtual /= null loop
         declare
            Exact : constant Placement_Key :=
              Key_Of
                (Virtual.Stream_ID,
                 Virtual.Alternate_Screen,
                 Virtual.Screen_Generation,
                 Virtual.Image_ID,
                 Virtual.Placement_ID);
            Fallback : constant Placement_Key :=
              Key_Of
                (Virtual.Stream_ID,
                 Virtual.Alternate_Screen,
                 Virtual.Screen_Generation,
                 Virtual.Image_ID,
                 0);
         begin
            if Virtual.Placement_ID /= 0
              and then not Item.Placements.Contains (Exact)
            then
               Item.Placements.Insert (Exact, Virtual);
            end if;
            if not Item.Placements.Contains (Fallback) then
               Item.Placements.Insert (Fallback, Virtual);
            end if;
         end;
         Virtual := Virtual.Next;
      end loop;

      while Conventional /= null loop
         declare
            Exact : constant Placement_Key :=
              Key_Of
                (Conventional.Stream_ID,
                 Conventional.Alternate_Screen,
                 Conventional.Screen_Generation,
                 Conventional.Image_ID,
                 Conventional.Placement_ID);
         begin
            if not Item.Conventionals.Contains (Exact) then
               Item.Conventionals.Insert (Exact, Conventional);
            end if;
         end;
         Conventional := Conventional.Next;
      end loop;

      while Object /= null loop
         declare
            Key : constant Object_Key :=
              (Stream_ID     => Terminal.App.Image_Store.Stream_ID (Object.all),
               Storage_Order =>
                 Terminal.App.Image_Store.Storage_Order (Object.all));
         begin
            if not Item.Objects.Contains (Key) then
               Item.Objects.Insert (Key, Object);
            end if;
         end;
         Object := Terminal.App.Image_Store.Next_Object (Object);
      end loop;
   end Build;

   procedure Index_Cells
     (Item     : in out Index;
      Snapshot : Terminal.Core.Render_Snapshot)
   is
   begin
      if Item.Origin_Epoch = Interfaces.Unsigned_64'Last then
         Item.Origins.Clear;
         Item.Origin_Epoch := 1;
      else
         Item.Origin_Epoch := Item.Origin_Epoch + 1;
      end if;

      for Row in 1 .. Snapshot.Rows loop
         for Col in 1 .. Snapshot.Cols loop
            declare
               Cell : constant Terminal.Core.Cell :=
                 Terminal.Core.Cell_At (Snapshot, Row, Col);
            begin
               if Cell.Image.Is_Placeholder
                 and then Cell.Image.Image_ID_Valid
               then
                  declare
                     Key : constant Placement_Key :=
                       Key_Of
                         (Snapshot.Graphics_Stream,
                          Snapshot.Alternate_Screen,
                          Snapshot.Screen_Generation,
                          Cell.Image.Image_ID,
                          Cell.Image.Placement_ID);
                     Position : Origin_Value :=
                       (Epoch => Item.Origin_Epoch, Row => Row, Col => Col);
                  begin
                     --  Ignore syntactically valid placeholder cells that do
                     --  not resolve to a retained virtual placement.  This
                     --  keeps the reusable origin map bounded by the placement
                     --  quota even when arbitrary placeholder text changes on
                     --  every frame.
                     if not Item.Placements.Contains (Key) then
                        null;
                     elsif Item.Origins.Contains (Key) then
                        Position := Item.Origins.Element (Key);
                        if Position.Epoch = Item.Origin_Epoch then
                           Position.Row := Integer'Min (Position.Row, Row);
                           Position.Col := Integer'Min (Position.Col, Col);
                        else
                           Position :=
                             (Epoch => Item.Origin_Epoch,
                              Row   => Row,
                              Col   => Col);
                        end if;
                        Item.Origins.Replace (Key, Position);
                     else
                        Item.Origins.Insert (Key, Position);
                     end if;
                  end;
               end if;
            end;
         end loop;
      end loop;
   end Index_Cells;

   function Find_Placement
     (Item              : Index;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Terminal.App.Image_Placements.Virtual_Placement_Access
   is
      Key : constant Placement_Key :=
        Key_Of
          (Stream_ID,
           Alternate_Screen,
           Screen_Generation,
           Image_ID,
           Placement_ID);
   begin
      if Item.Placements.Contains (Key) then
         return Item.Placements.Element (Key);
      end if;
      return null;
   end Find_Placement;

   function Find_Conventional
     (Item              : Index;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Terminal.App.Image_Placements.Conventional_Placement_Access
   is
      Key : constant Placement_Key :=
        Key_Of
          (Stream_ID,
           Alternate_Screen,
           Screen_Generation,
           Image_ID,
           Placement_ID);
   begin
      if Item.Conventionals.Contains (Key) then
         return Item.Conventionals.Element (Key);
      end if;
      return null;
   end Find_Conventional;

   function Find_Object
     (Item          : Index;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64)
      return Terminal.App.Image_Store.Image_Object_Access
   is
      Key : constant Object_Key :=
        (Stream_ID => Stream_ID, Storage_Order => Storage_Order);
   begin
      if Item.Objects.Contains (Key) then
         return Item.Objects.Element (Key);
      end if;
      return null;
   end Find_Object;

   function Find_Origin
     (Item              : Index;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID;
      Row               : out Integer;
      Col               : out Integer) return Boolean
   is
      Key : constant Placement_Key :=
        Key_Of
          (Stream_ID,
           Alternate_Screen,
           Screen_Generation,
           Image_ID,
           Placement_ID);
      Position : Origin_Value;
   begin
      Row := 0;
      Col := 0;
      if not Item.Origins.Contains (Key) then
         return False;
      end if;
      Position := Item.Origins.Element (Key);
      if Position.Epoch /= Item.Origin_Epoch then
         return False;
      end if;
      Row := Position.Row;
      Col := Position.Col;
      return True;
   end Find_Origin;
end Terminal.App.Placeholder_Index;
