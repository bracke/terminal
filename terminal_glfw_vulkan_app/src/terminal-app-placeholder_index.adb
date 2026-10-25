package body Terminal.App.Placeholder_Index is
   use type Interfaces.Unsigned_64;
   use type Terminal.App.Image_Placements.Virtual_Placement_Access;
   use type Terminal.App.Image_Store.Image_Object_Access;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.Core.Graphics_Screen_Generation;
   use type Terminal.Core.Graphics_Stream_ID;

   function Hash_Placement
     (Key : Placement_Key) return Ada.Containers.Hash_Type
   is
      Mixed : constant Interfaces.Unsigned_64 :=
        Interfaces.Unsigned_64 (Key.Image_ID) * 65_599
        + Interfaces.Unsigned_64 (Key.Placement_ID);
   begin
      return Ada.Containers.Hash_Type'Mod (Mixed);
   end Hash_Placement;

   function Hash_Storage_Order
     (Key : Interfaces.Unsigned_64) return Ada.Containers.Hash_Type
   is (Ada.Containers.Hash_Type'Mod (Key));

   procedure Build
     (Item              : in out Index;
      Placements        : Terminal.App.Image_Placements.Virtual_Placement_Access;
      Images            : Terminal.App.Image_Store.Store;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation)
   is
      Placement : Terminal.App.Image_Placements.Virtual_Placement_Access :=
        Placements;
      Object : Terminal.App.Image_Store.Image_Object_Access :=
        Terminal.App.Image_Store.First (Images);
   begin
      Item.Placements.Clear;
      Item.Objects.Clear;
      while Placement /= null loop
         if Placement.Stream_ID = Stream_ID
           and then Placement.Alternate_Screen = Alternate_Screen
           and then Placement.Screen_Generation = Screen_Generation
         then
            declare
               Exact : constant Placement_Key :=
                 (Placement.Image_ID, Placement.Placement_ID);
               Fallback : constant Placement_Key :=
                 (Placement.Image_ID, 0);
            begin
               if Placement.Placement_ID /= 0
                 and then not Item.Placements.Contains (Exact)
               then
                  Item.Placements.Insert (Exact, Placement);
               end if;
               --  Placements are linked newest first.  The first zero-ID
               --  fallback therefore preserves the terminal's deterministic
               --  placeholder resolution rule.
               if not Item.Placements.Contains (Fallback) then
                  Item.Placements.Insert (Fallback, Placement);
               end if;
            end;
         end if;
         Placement := Placement.Next;
      end loop;

      while Object /= null loop
         if Terminal.App.Image_Store.Stream_ID (Object.all) = Stream_ID then
            Item.Objects.Insert
              (Terminal.App.Image_Store.Storage_Order (Object.all), Object);
         end if;
         Object := Terminal.App.Image_Store.Next_Object (Object);
      end loop;
   end Build;

   function Find_Placement
     (Item         : Index;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Terminal.App.Image_Placements.Virtual_Placement_Access
   is
      Key : constant Placement_Key := (Image_ID, Placement_ID);
   begin
      if Item.Placements.Contains (Key) then
         return Item.Placements.Element (Key);
      end if;
      return null;
   end Find_Placement;

   function Find_Object
     (Item          : Index;
      Storage_Order : Interfaces.Unsigned_64)
      return Terminal.App.Image_Store.Image_Object_Access
   is
   begin
      if Item.Objects.Contains (Storage_Order) then
         return Item.Objects.Element (Storage_Order);
      end if;
      return null;
   end Find_Object;
end Terminal.App.Placeholder_Index;
