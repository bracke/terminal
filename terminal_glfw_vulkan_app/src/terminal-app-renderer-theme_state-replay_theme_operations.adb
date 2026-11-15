with Terminal.App.Owned_Image_Data;
with Terminal.App.Renderer.Theme_Replay_Storage;
with Terminal.App.Renderer.Theme_Pixels;

separate (Terminal.App.Renderer.Theme_State)
function Replay_Theme_Operations
  (R      : in out Renderer;
   Object : Image_Object_Access) return Boolean
is
   Position : Themes.Cursor;
   Frame_Position : Frames.Cursor;
   Replay_Rejected : exception;
   package Replay_Storage renames
     Terminal.App.Renderer.Theme_Replay_Storage;
   package Pixels renames Terminal.App.Renderer.Theme_Pixels;
   Frame_Index_Last : constant Positive :=
     Positive'Max (1, Frames.Count (Object));
   type Frame_Cursor_Index is array
     (Positive range <>) of Frames.Cursor;
   type Frame_Presence_Index is array
     (Positive range <>) of Boolean;
   type Replay_Context (Frame_Last : Positive) is limited record
      Canvas_Length   : Natural := 0;
      Canvas_A        : Terminal.App.Owned_Image_Data.Owner;
      Canvas_B        : Terminal.App.Owned_Image_Data.Owner;
      Data_Pin        : Terminal.App.Image_Store.Data_Borrow;
      Archived_Frames : Replay_Storage.Workspace;
      Frame_Positions : Frame_Cursor_Index (1 .. Frame_Last);
      Frame_Present   : Frame_Presence_Index (1 .. Frame_Last) :=
        (others => False);
   end record;
   Context : Replay_Context (Frame_Index_Last);

   function Target_Bytes
     (Context  : in out Replay_Context;
      Object   : Image_Object_Access;
      Number   : Positive;
      Create    : Boolean := False)
      return access Terminal.App.Owned_Image_Data.Owner
   is
      Existing : access Terminal.App.Owned_Image_Data.Owner := null;
      New_Bytes : Terminal.App.Owned_Image_Data.Owner;
      Copied : Boolean := False;
   begin
      if Number > Context.Frame_Last then
         return null;
      end if;
      Existing := Replay_Storage.Find (Context.Archived_Frames, Number);
      if Existing /= null then
         return Existing;
      end if;
      if not Create and then not Context.Frame_Present (Number) then
         return null;
      end if;
      --  Allocate the byte storage separately so failure to allocate the
      --  list node cannot orphan an already-created canvas.
      Terminal.App.Owned_Image_Data.Allocate
        (New_Bytes, Context.Canvas_Length);
      if Create then
         Terminal.App.Owned_Image_Data.Fill (New_Bytes, 0);
      elsif Number > 1 then
         declare
            Found : Boolean := False;
            Visited : Boolean;
            procedure Copy_Source
              (Source : Terminal.Common.Bytes.Byte_Array) is
            begin
               if Source'Length >= Context.Canvas_Length then
                  Terminal.App.Owned_Image_Data.Copy
                    (New_Bytes,
                     Source
                       (Source'First
                        .. Source'First + Context.Canvas_Length - 1));
                  Found := True;
               end if;
            end Copy_Source;
         begin
            Visited := Frames.Visit_Data
              (Context.Data_Pin, Context.Frame_Positions (Number),
               Copy_Source'Access);
            if not Visited or else not Found then
               return null;
            end if;
         end;
      else
         declare
            procedure Copy_Frame
              (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
            begin
               Animation_State.Copy_Frame_To_RGBA
                 (Object, Number, Bytes, Copied);
            end Copy_Frame;
         begin
            Terminal.App.Owned_Image_Data.Modify
              (New_Bytes, Copy_Frame'Access);
         end;
         if not Copied then
            return null;
         end if;
      end if;
      return Replay_Storage.Insert
        (Context.Archived_Frames, Number, New_Bytes);
   end Target_Bytes;

   procedure Copy_Replay_Frame_To_RGBA
     (Context  : in out Replay_Context;
      Object   : Image_Object_Access;
      Number   : Positive;
      Target   : in out Terminal.Common.Bytes.Byte_Array;
      Valid    : out Boolean)
   is
      Source : constant access Terminal.App.Owned_Image_Data.Owner :=
        Target_Bytes (Context, Object, Number);
      procedure Copy (Bytes : Terminal.Common.Bytes.Byte_Array) is
      begin
         Target := Bytes;
         Valid := True;
      end Copy;
   begin
      Valid := False;
      if Source = null
        or else Terminal.App.Owned_Image_Data.Length (Source.all) /= Target'Length
      then
         return;
      end if;
      Terminal.App.Owned_Image_Data.Read (Source.all, Copy'Access);
   end Copy_Replay_Frame_To_RGBA;

   procedure Load_Canvas
     (Context : in out Replay_Context;
      Object  : Image_Object_Access;
      Number : Positive;
      Canvas : in out Terminal.App.Owned_Image_Data.Owner;
      Loaded : out Boolean)
   is
      procedure Copy (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
      begin
         Copy_Replay_Frame_To_RGBA
           (Context, Object, Number, Bytes, Loaded);
      end Copy;
   begin
      Terminal.App.Owned_Image_Data.Modify (Canvas, Copy'Access);
   end Load_Canvas;

   procedure Set_Background
     (Object : Image_Object_Access;
      Canvas : in out Terminal.App.Owned_Image_Data.Owner;
      Color  : Terminal.Core.Graphics_ID)
   is
      procedure Fill (Bytes : in out Terminal.Common.Bytes.Byte_Array) is
      begin
         Pixels.Fill_Background
           (Bytes, Positive (Object.Pixel_Width),
            Positive (Object.Pixel_Height), Color);
      end Fill;
   begin
      Terminal.App.Owned_Image_Data.Modify (Canvas, Fill'Access);
   end Set_Background;

   procedure Copy_Canvas
     (Canvas : Terminal.App.Owned_Image_Data.Owner;
      Target : access Terminal.App.Owned_Image_Data.Owner;
      Copied : out Boolean)
   is
      procedure Copy (Bytes : Terminal.Common.Bytes.Byte_Array) is
      begin
         if Target = null
           or else Terminal.App.Owned_Image_Data.Length (Target.all) /=
             Bytes'Length
         then
            Copied := False;
         else
            Terminal.App.Owned_Image_Data.Copy (Target.all, Bytes);
            Copied := True;
         end if;
      end Copy;
   begin
      Copied := False;
      Terminal.App.Owned_Image_Data.Read (Canvas, Copy'Access);
   end Copy_Canvas;

   procedure Apply_Composition_Operation
     (Context   : in out Replay_Context;
      Object    : Image_Object_Access;
      Operation : Terminal.App.Image_Store.Theme_Operation_Descriptor)
   is separate;

   procedure Apply_Data_Operation
     (Context   : in out Replay_Context;
      R         : in out Renderer;
      Object    : Image_Object_Access;
      Operation : Terminal.App.Image_Store.Theme_Operation_Descriptor;
      Position  : Themes.Cursor)
   is separate;

   procedure Publish_Replayed_Frames
     (Context : in out Replay_Context;
      R       : in out Renderer;
      Object  : Image_Object_Access) is separate;
begin
   if Object = null
     or else Themes.Count (Object) = 0
   then
      return True;
   elsif Object.Pixel_Width = 0
     or else Object.Pixel_Height = 0
     or else Object.Pixel_Width > Natural'Last / Object.Pixel_Height
     or else Object.Pixel_Width * Object.Pixel_Height > Natural'Last / 4
   then
      return False;
   end if;
   Context.Canvas_Length := Object.Pixel_Width * Object.Pixel_Height * 4;
   Replay_Storage.Initialize (Context.Archived_Frames, Frame_Index_Last);
   Terminal.App.Owned_Image_Data.Allocate
     (Context.Canvas_A, Context.Canvas_Length);
   Terminal.App.Owned_Image_Data.Allocate
     (Context.Canvas_B, Context.Canvas_Length);
   Terminal.App.Image_Store.Borrow (Context.Data_Pin, Object);
   Frame_Position := Frames.First (Context.Data_Pin);
   while Frames.Has_Element (Frame_Position) loop
      declare
         Frame : constant Frames.Frame_Descriptor :=
           Frames.Descriptor (Context.Data_Pin, Frame_Position);
      begin
         if Frame.Number <= Context.Frame_Positions'Last then
            Context.Frame_Positions (Frame.Number) := Frame_Position;
            Context.Frame_Present (Frame.Number) := True;
         end if;
      end;
      Frames.Next (Context.Data_Pin, Frame_Position);
   end loop;
   Position := Themes.First (Context.Data_Pin);
   while Themes.Has_Element (Position) loop
      declare
         Operation : constant
           Terminal.App.Image_Store.Theme_Operation_Descriptor :=
           Themes.Descriptor (Context.Data_Pin, Position);
      begin
         if Operation.Is_Composition then
            Apply_Composition_Operation (Context, Object, Operation);
         else
            Apply_Data_Operation (Context, R, Object, Operation, Position);
         end if;
      end;
      Themes.Next (Context.Data_Pin, Position);
   end loop;
   Terminal.App.Image_Store.Release (Context.Data_Pin);
   --  Replay uses private working copies.  Publish them only after every
   --  operation has succeeded, so a failed recolor cannot partially mutate
   --  store-owned image memory.
   Publish_Replayed_Frames (Context, R, Object);
   return True;
exception
   when Storage_Error =>
      return False;
   when Replay_Rejected =>
      return False;
end Replay_Theme_Operations;
