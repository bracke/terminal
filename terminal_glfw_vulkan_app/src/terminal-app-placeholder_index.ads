with Ada.Containers;
with Ada.Containers.Hashed_Maps;
with Interfaces;
with Terminal.App.Image_Placements;
with Terminal.App.Image_Store;
with Terminal.Core;

package Terminal.App.Placeholder_Index is
   type Index is limited private;

   procedure Build
     (Item              : in out Index;
      Virtuals          : Terminal.App.Image_Placements.Virtual_Placement_Access;
      Conventionals     :
        Terminal.App.Image_Placements.Conventional_Placement_Access;
      Images            : Terminal.App.Image_Store.Store);

   procedure Index_Cells
     (Item     : in out Index;
      Snapshot : Terminal.Core.Render_Snapshot);

   function Find_Placement
     (Item              : Index;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Terminal.App.Image_Placements.Virtual_Placement_Access;

   function Find_Conventional
     (Item              : Index;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Terminal.App.Image_Placements.Conventional_Placement_Access;

   function Find_Object
     (Item          : Index;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64)
      return Terminal.App.Image_Store.Image_Object_Access;

   function Find_Origin
     (Item              : Index;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID;
      Row               : out Integer;
      Col               : out Integer) return Boolean;

private
   type Placement_Key is record
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
   end record;

   type Object_Key is record
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64;
   end record;

   type Origin_Value is record
      Epoch : Interfaces.Unsigned_64 := 0;
      Row   : Integer := 0;
      Col   : Integer := 0;
   end record;

   function Hash_Placement
     (Key : Placement_Key) return Ada.Containers.Hash_Type;
   function Hash_Storage_Order
     (Key : Object_Key) return Ada.Containers.Hash_Type;

   package Placement_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Placement_Key,
      Element_Type    => Terminal.App.Image_Placements.Virtual_Placement_Access,
      Hash            => Hash_Placement,
      Equivalent_Keys => "=",
      "="             => Terminal.App.Image_Placements."=");
   package Conventional_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Placement_Key,
      Element_Type    =>
        Terminal.App.Image_Placements.Conventional_Placement_Access,
      Hash            => Hash_Placement,
      Equivalent_Keys => "=",
      "="             => Terminal.App.Image_Placements."=");
   package Object_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Object_Key,
      Element_Type    => Terminal.App.Image_Store.Image_Object_Access,
      Hash            => Hash_Storage_Order,
      Equivalent_Keys => "=",
      "="             => Terminal.App.Image_Store."=");
   package Origin_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Placement_Key,
      Element_Type    => Origin_Value,
      Hash            => Hash_Placement,
      Equivalent_Keys => "=");

   type Index is limited record
      Placements    : Placement_Maps.Map;
      Conventionals : Conventional_Maps.Map;
      Objects       : Object_Maps.Map;
      Origins       : Origin_Maps.Map;
      Origin_Epoch  : Interfaces.Unsigned_64 := 0;
   end record;
end Terminal.App.Placeholder_Index;
