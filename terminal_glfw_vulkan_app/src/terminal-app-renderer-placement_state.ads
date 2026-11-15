with Terminal.App.Graphics;
with Terminal.App.Render_Model;
with Terminal.Core;
with Interfaces;

private package Terminal.App.Renderer.Placement_State is
   type Virtual_Placement_Value is record
      Exists : Boolean := False;
      Value  : Virtual_Placement_State := (others => <>);
   end record;

   type Conventional_Placement_Value is record
      Exists : Boolean := False;
      Value  : Conventional_Placement_State := (others => <>);
   end record;

   function Value_Of
     (Placement : Conventional_Placement_Access)
      return Conventional_Placement_Value;
   function Stored_Placement_Count (R : Renderer) return Natural;
   procedure Release_All (R : in out Renderer);
   procedure Release_All (Object : in out Renderer_Graphics_State);
   procedure Release_Unowned
     (Placement : in out Virtual_Placement_Access);
   procedure Release_Unowned
     (Placement : in out Conventional_Placement_Access);

   type Virtual_Cursor is private;
   type Conventional_Cursor is private;
   function First_Virtual (R : Renderer) return Virtual_Cursor;
   function First_Conventional (R : Renderer) return Conventional_Cursor;
   function Has_Element (Position : Virtual_Cursor) return Boolean;
   function Has_Element (Position : Conventional_Cursor) return Boolean;
   function Element
     (Position : Virtual_Cursor) return Virtual_Placement_State;
   function Element
     (Position : Conventional_Cursor) return Conventional_Placement_State;
   procedure Update
     (R        : in out Renderer;
      Position : Virtual_Cursor;
      Process  : not null access procedure
        (Placement : in out Virtual_Placement_State));
   procedure Update
     (R        : in out Renderer;
      Position : Conventional_Cursor;
      Process  : not null access procedure
        (Placement : in out Conventional_Placement_State));
   procedure Update_All
     (R       : in out Renderer;
      Process : not null access procedure
        (Placement : in out Virtual_Placement_State));
   procedure Update_All
     (R       : in out Renderer;
      Process : not null access procedure
        (Placement : in out Conventional_Placement_State));
   procedure Advance (Position : in out Virtual_Cursor);
   procedure Advance (Position : in out Conventional_Cursor);
   procedure Validate_Delete (R : Renderer; Position : Virtual_Cursor);
   procedure Validate_Delete (R : Renderer; Position : Conventional_Cursor);
   procedure Delete (R : in out Renderer; Position : in out Virtual_Cursor);
   procedure Delete
     (R : in out Renderer; Position : in out Conventional_Cursor);
   procedure Delete_Conventional_If
     (R             : in out Renderer;
      Matches       : not null access function
        (Placement : Conventional_Placement_State) return Boolean;
      Before_Delete : access procedure
        (Placement : Conventional_Placement_State) := null);

   procedure Invalidate_Placement_Index (R : in out Renderer);
   procedure Rebuild_Placement_Index (R : in out Renderer);
   procedure Prepare_Index
     (R        : in out Renderer;
      Snapshot : Terminal.Core.Render_Snapshot);
   procedure Prepend_Virtual_Placement
     (R : in out Renderer; Placement : in out Virtual_Placement_Access);
   procedure Prepend_Conventional_Placement
     (R : in out Renderer; Placement : in out Conventional_Placement_Access);
   function Find_Virtual_Placement
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Value;
   function Find_Addressed_Virtual_Placement
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Virtual_Placement_Value;
   procedure Update_Addressed_Virtual_Placement
     (R            : in out Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
      Process      : not null access procedure
        (Placement : in out Virtual_Placement_State));
   function Has_Virtual_Placement
     (R : Renderer; Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID : Terminal.Core.Graphics_ID) return Boolean;

   function Find_Conventional_Placement
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Value;
   function Find_Addressed_Conventional_Placement
     (R            : Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID)
      return Conventional_Placement_Value;
   procedure Update_Addressed_Conventional_Placement
     (R            : in out Renderer;
      Stream_ID    : Terminal.Core.Graphics_Stream_ID;
      Image_ID     : Terminal.Core.Graphics_ID;
      Placement_ID : Terminal.Core.Graphics_ID;
      Process      : not null access procedure
        (Placement : in out Conventional_Placement_State));
   function Has_Conventional_Placement
     (R : Renderer; Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID : Terminal.Core.Graphics_ID) return Boolean;

   function Has_Image_Placement
     (R : Renderer; Stream_ID : Terminal.Core.Graphics_Stream_ID;
      Image_ID : Terminal.Core.Graphics_ID) return Boolean;
   function Has_Image_Placement
     (R : in out Renderer; Object : Image_Object_Access) return Boolean;
   function Has_Conventional_Storage_Order
     (R             : Renderer;
      Stream_ID     : Terminal.Core.Graphics_Stream_ID;
      Storage_Order : Interfaces.Unsigned_64) return Boolean;
   function Has_Implicit_Virtual
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Storage_Order     : Interfaces.Unsigned_64) return Boolean;
   function Has_Implicit_Conventional
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Storage_Order     : Interfaces.Unsigned_64) return Boolean;
   procedure For_Each_Visible_Image_Object
     (R       : Renderer;
      Process : not null access procedure
        (Stream_ID     : Terminal.Core.Graphics_Stream_ID;
         Storage_Order : Interfaces.Unsigned_64));
   function Parent_Placement_Exists
     (R                 : Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Alternate_Screen  : Boolean;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID) return Boolean;

   procedure Delete_Virtual_Placements
     (R               : in out Renderer;
      Stream_ID       : Terminal.Core.Graphics_Stream_ID;
      Image_ID        : Terminal.Core.Graphics_ID;
      Placement_ID    : Terminal.Core.Graphics_ID := 0;
      Match_Placement : Boolean := False);
   procedure Delete_Conventional_Placements
     (R                 : in out Renderer;
      Stream_ID         : Terminal.Core.Graphics_Stream_ID;
      Image_ID          : Terminal.Core.Graphics_ID;
      Placement_ID      : Terminal.Core.Graphics_ID := 0;
      Match_Placement   : Boolean := False;
      Match_Protocol    : Boolean := True;
      Protocol          : Terminal.App.Render_Model.Image_Protocol :=
        Terminal.App.Render_Model.Image_Kitty;
      Match_Screen      : Boolean := False;
      Alternate_Screen  : Boolean := False;
      Screen_Generation : Terminal.Core.Graphics_Screen_Generation := 0);

   procedure Move_Relative_Descendants
     (R                   : in out Renderer;
      Stream_ID           : Terminal.Core.Graphics_Stream_ID;
      Parent_Image_ID     : Terminal.Core.Graphics_ID;
      Parent_Placement_ID : Terminal.Core.Graphics_ID;
      Alternate_Screen    : Boolean;
      Screen_Generation   : Terminal.Core.Graphics_Screen_Generation);

   subtype Placement_Geometry is Terminal.App.Image_Placements.Geometry;
   function Resolve_Placement_Geometry
     (R            : Renderer;
      Pixel_Width  : Natural;
      Pixel_Height : Natural;
      Header       : Terminal.App.Graphics.Graphics_Header)
      return Placement_Geometry;
   function Resolve_Placement_Geometry
     (R      : Renderer;
      Object : Image_Object_Access;
      Header : Terminal.App.Graphics.Graphics_Header)
      return Placement_Geometry;
private
   type Virtual_Cursor is record
      Previous : Virtual_Placement_Access := null;
      Current  : Virtual_Placement_Access := null;
   end record;
   type Conventional_Cursor is record
      Previous : Conventional_Placement_Access := null;
      Current  : Conventional_Placement_Access := null;
   end record;
end Terminal.App.Renderer.Placement_State;
