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
      Placements        : Terminal.App.Image_Placements.Virtual_Placement_Access;
      Images            : Terminal.App.Image_Store.Store;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation);

   function Find_Placement
     (Item         : Index;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Terminal.App.Image_Placements.Virtual_Placement_Access;

   function Find_Object
     (Item          : Index;
      Storage_Order : Interfaces.Unsigned_64)
      return Terminal.App.Image_Store.Image_Object_Access;

private
   type Placement_Key is record
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
   end record;

   function Hash_Placement
     (Key : Placement_Key) return Ada.Containers.Hash_Type;
   function Hash_Storage_Order
     (Key : Interfaces.Unsigned_64) return Ada.Containers.Hash_Type;

   package Placement_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Placement_Key,
      Element_Type    => Terminal.App.Image_Placements.Virtual_Placement_Access,
      Hash            => Hash_Placement,
      Equivalent_Keys => "=",
      "="             => Terminal.App.Image_Placements."=");
   package Object_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Interfaces.Unsigned_64,
      Element_Type    => Terminal.App.Image_Store.Image_Object_Access,
      Hash            => Hash_Storage_Order,
      Equivalent_Keys => Interfaces."=",
      "="             => Terminal.App.Image_Store."=");

   type Index is limited record
      Placements : Placement_Maps.Map;
      Objects    : Object_Maps.Map;
   end record;
end Terminal.App.Placeholder_Index;
