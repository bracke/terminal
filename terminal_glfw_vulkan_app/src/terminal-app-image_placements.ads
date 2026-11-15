with Ada.Finalization;
with Ada.Containers;
with Ada.Containers.Hashed_Maps;
with Interfaces;
with Terminal.App.Graphics;
with Terminal.App.Render_Model;
with Terminal.Common.Graphics_Limits;
with Terminal.Core;

private package Terminal.App.Image_Placements is
   type Virtual_Placement_State is record
      Stream_ID      : Terminal.Core.Graphics_Stream_ID := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Image_ID       : Terminal.Core.Graphics_ID := 0;
      Image_Storage_Order : Interfaces.Unsigned_64 := 0;
      Placement_ID   : Terminal.Core.Graphics_ID := 0;
      Columns        : Positive := 1;
      Rows           : Positive := 1;
      Source_X       : Natural := 0;
      Source_Y       : Natural := 0;
      Source_Width   : Natural := 0;
      Source_Height  : Natural := 0;
      Cell_X         : Natural := 0;
      Cell_Y         : Natural := 0;
      Draw_Offset_X  : Natural := 0;
      Draw_Offset_Y  : Natural := 0;
      Draw_Width     : Positive := 1;
      Draw_Height    : Positive := 1;
      Z_Index        : Integer := 0;
      Parent_Offset_X : Integer := 0;
      Parent_Offset_Y : Integer := 0;
   end record;
   type Virtual_Placement is limited private;
   type Virtual_Placement_Access is access Virtual_Placement;
   type Virtual_Placement_Link is limited private;
   function State
     (Placement : not null Virtual_Placement_Access)
      return Virtual_Placement_State;
   procedure Configure_Unlinked
     (Placement : not null Virtual_Placement_Access;
      Process   : not null access procedure
        (Item : in out Virtual_Placement_State));

   type Conventional_Placement_State is record
      Stream_ID      : Terminal.Core.Graphics_Stream_ID := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Image_ID       : Terminal.Core.Graphics_ID := 0;
      Image_Storage_Order : Interfaces.Unsigned_64 := 0;
      Protocol       : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Kitty;
      Placement_ID   : Terminal.Core.Graphics_ID := 0;
      Row            : Integer := 1;
      Col            : Positive := 1;
      Columns        : Positive := 1;
      Rows           : Positive := 1;
      Source_X       : Natural := 0;
      Source_Y       : Natural := 0;
      Source_Width   : Natural := 0;
      Source_Height  : Natural := 0;
      Cell_X         : Natural := 0;
      Cell_Y         : Natural := 0;
      Draw_Offset_X  : Natural := 0;
      Draw_Offset_Y  : Natural := 0;
      Draw_Width     : Positive := 1;
      Draw_Height    : Positive := 1;
      Z_Index        : Integer := 0;
      Parent_Image_ID : Terminal.Core.Graphics_ID := 0;
      Parent_Placement_ID : Terminal.Core.Graphics_ID := 0;
      Parent_Offset_X : Integer := 0;
      Parent_Offset_Y : Integer := 0;
      Scroll_Sequence : Terminal.Core.Graphics_Scroll_Sequence := 0;
      Clip_Top        : Natural := 0;
      Clip_Bottom     : Natural := 0;
      History_Attached : Boolean := False;
   end record;
   type Conventional_Placement is limited private;
   type Conventional_Placement_Access is access Conventional_Placement;
   type Conventional_Placement_Link is limited private;
   function State
     (Placement : not null Conventional_Placement_Access)
      return Conventional_Placement_State;
   procedure Configure_Unlinked
     (Placement : not null Conventional_Placement_Access;
      Process   : not null access procedure
        (Item : in out Conventional_Placement_State));

   --  Owns both placement lists and their shared quota accounting.  Protocol
   --  code may traverse the lists through First_* and remove a known node,
   --  but cannot change a head or the count independently.
   type Store is new Ada.Finalization.Limited_Controlled with private;

   function Count (Container : Store) return Natural;
   function First_Virtual
     (Container : Store) return Virtual_Placement_Access;
   function First_Conventional
     (Container : Store) return Conventional_Placement_Access;
   function Next
     (Placement : Virtual_Placement_Access) return Virtual_Placement_Access;
   function Next
     (Placement : Conventional_Placement_Access)
      return Conventional_Placement_Access;

   function Find_Virtual
     (Container         : Store;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Access;
   function Find_Addressed_Virtual
     (Container    : Store;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Access;
   function Has_Virtual
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID) return Boolean;

   function Find_Conventional
     (Container         : Store;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Access;
   function Find_Addressed_Conventional
     (Container    : Store;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Access;
   function Has_Conventional
     (Container : Store;
      Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID  : Terminal.Core.Graphics_ID) return Boolean;

   procedure Move_Relative_Descendants
     (Container           : in out Store;
      Stream_ID           : Terminal.Core.Graphics_Stream_ID;
      Parent_Image_ID     : Terminal.Core.Graphics_ID;
      Parent_Placement_ID : Terminal.Core.Graphics_ID;
      Alternate_Screen    : Boolean;
      Screen_Generation   : Terminal.Core.Graphics_Screen_Generation;
      Maximum_Depth       : Positive);

   procedure Prepend
     (Container : in out Store;
      Placement : Virtual_Placement_Access);
   procedure Prepend
     (Container : in out Store;
      Placement : Conventional_Placement_Access);
   --  Process receives an unlinked candidate copy.  Its changes are committed
   --  to the live placement and indexes only when it returns normally.
   procedure Update
     (Container : in out Store;
      Placement : Virtual_Placement_Access;
      Process   : not null access procedure
        (Item : in out Virtual_Placement_State));
   procedure Update
     (Container : in out Store;
      Placement : Conventional_Placement_Access;
      Process   : not null access procedure
        (Item : in out Conventional_Placement_State));
   --  Applies a transaction to every placement and rebuilds each affected
   --  index once. No live state changes if Process or index construction fails.
   procedure Update_All
     (Container : in out Store;
      Process   : not null access procedure
        (Item : in out Virtual_Placement_State));
   procedure Update_All
     (Container : in out Store;
      Process   : not null access procedure
        (Item : in out Conventional_Placement_State));

   procedure Validate_Remove
     (Container : Store;
      Previous  : Virtual_Placement_Access;
      Current   : Virtual_Placement_Access);
   procedure Validate_Remove
     (Container : Store;
      Previous  : Conventional_Placement_Access;
      Current   : Conventional_Placement_Access);
   procedure Remove
     (Container : in out Store;
      Previous  : Virtual_Placement_Access;
      Current   : in out Virtual_Placement_Access;
      Next      : out Virtual_Placement_Access);
   procedure Remove
     (Container : in out Store;
      Previous  : Conventional_Placement_Access;
      Current   : in out Conventional_Placement_Access;
      Next      : out Conventional_Placement_Access);

   procedure Release_Unowned
     (Placement : in out Virtual_Placement_Access);
   procedure Release_Unowned
     (Placement : in out Conventional_Placement_Access);
   procedure Release (Container : in out Store);
   overriding procedure Finalize (Container : in out Store);

   type Geometry is record
      Valid         : Boolean := False;
      Columns       : Positive := 1;
      Rows          : Positive := 1;
      Draw_Offset_X : Natural := 0;
      Draw_Offset_Y : Natural := 0;
      Draw_Width    : Positive := 1;
      Draw_Height   : Positive := 1;
   end record;

   function Resolve
     (Cell_Width   : Natural;
      Cell_Height  : Natural;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Header       : Terminal.App.Graphics.Graphics_Header) return Geometry;

private
   type Placement_Key is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID := 0;
      Alternate_Screen : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0;
      Image_ID : Terminal.Core.Graphics_ID := 0;
      Placement_ID : Terminal.Core.Graphics_ID := 0;
   end record;
   type Address_Key is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID := 0;
      Image_ID : Terminal.Core.Graphics_ID := 0;
      Placement_ID : Terminal.Core.Graphics_ID := 0;
   end record;
   type Image_Key is record
      Stream_ID : Terminal.Core.Graphics_Stream_ID := 0;
      Image_ID : Terminal.Core.Graphics_ID := 0;
   end record;
   function Hash (Key : Placement_Key) return Ada.Containers.Hash_Type;
   function Hash (Key : Address_Key) return Ada.Containers.Hash_Type;
   function Hash (Key : Image_Key) return Ada.Containers.Hash_Type;

   package Virtual_Placement_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Placement_Key,
      Element_Type    => Virtual_Placement_Access,
      Hash            => Hash,
      Equivalent_Keys => "=");
   package Conventional_Placement_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Placement_Key,
      Element_Type    => Conventional_Placement_Access,
      Hash            => Hash,
      Equivalent_Keys => "=");
   package Virtual_Address_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Address_Key,
      Element_Type    => Virtual_Placement_Access,
      Hash            => Hash,
      Equivalent_Keys => "=");
   package Conventional_Address_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Address_Key,
      Element_Type    => Conventional_Placement_Access,
      Hash            => Hash,
      Equivalent_Keys => "=");
   package Image_Count_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Image_Key,
      Element_Type    => Natural,
      Hash            => Hash,
      Equivalent_Keys => "=");

   type Virtual_Placement_Link is limited record
      Next_Link : Virtual_Placement_Access := null;
      Linked    : Boolean := False;
   end record;
   type Conventional_Placement_Link is limited record
      Next_Link : Conventional_Placement_Access := null;
      Linked    : Boolean := False;
   end record;

   type Virtual_Placement is limited record
      Link  : Virtual_Placement_Link;
      State : aliased Virtual_Placement_State;
   end record;
   type Conventional_Placement is limited record
      Link  : Conventional_Placement_Link;
      State : aliased Conventional_Placement_State;
   end record;

   type Store is new Ada.Finalization.Limited_Controlled with record
      Virtual_Head      : Virtual_Placement_Access := null;
      Conventional_Head : Conventional_Placement_Access := null;
      Placement_Count   : Natural range
        0 .. Terminal.Common.Graphics_Limits.Max_Placements := 0;
      Virtual_By_Key : Virtual_Placement_Maps.Map;
      Conventional_By_Key : Conventional_Placement_Maps.Map;
      Virtual_By_Address : Virtual_Address_Maps.Map;
      Conventional_By_Address : Conventional_Address_Maps.Map;
      Virtual_Image_Counts : Image_Count_Maps.Map;
      Conventional_Image_Counts : Image_Count_Maps.Map;
   end record;
end Terminal.App.Image_Placements;
