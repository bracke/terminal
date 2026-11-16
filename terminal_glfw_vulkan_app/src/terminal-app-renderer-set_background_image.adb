with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.IO_Exceptions;
with Ada.Unchecked_Deallocation;

separate (Terminal.App.Renderer)
procedure Set_Background_Image
  (R               : in out Renderer;
   Path            : String;
   Opacity_Percent : Natural;
   Status          : out Background_Update_Status)
is
   package SIO renames Ada.Streams.Stream_IO;
   use type Ada.Streams.Stream_IO.Count;
   use type Ada.Streams.Stream_Element_Offset;
   use type Terminal.App.Image_Media.Decode_Status;

   type Stream_Array_Access is access Ada.Streams.Stream_Element_Array;
   type Byte_Array_Access is access Terminal.Common.Bytes.Byte_Array;
   procedure Free_Stream is new Ada.Unchecked_Deallocation
     (Ada.Streams.Stream_Element_Array, Stream_Array_Access);
   procedure Free_Bytes is new Ada.Unchecked_Deallocation
     (Terminal.Common.Bytes.Byte_Array, Byte_Array_Access);

   File : SIO.File_Type;
   Encoded : Stream_Array_Access := null;
   Bytes : Byte_Array_Access := null;
   Last : Ada.Streams.Stream_Element_Offset;
   Image : Terminal.App.Image_Media.Decoded_Image;
   Decode_Status : Terminal.App.Image_Media.Decode_Status;
   Image_Owner : Terminal.App.Owned_Image_Data.Owner;
   Stored : Image_Object_Access := null;
   Background_Stream : constant Terminal.Core.Graphics_Stream_ID :=
     Terminal.Core.Graphics_Stream_ID'Last;
   Background_ID : constant Terminal.Core.Graphics_ID :=
     Terminal.Core.Graphics_ID'Last;

   procedure Clear_Current is
   begin
      if R.View_State.Background_Object /= null then
         Terminal.App.Image_Store.Delete_Object
           (R.Graphics_State.Resources.Image_Objects,
            R.View_State.Background_Object);
      end if;
      R.View_State.Background_Object := null;
   end Clear_Current;

   procedure Release_Input is
   begin
      if SIO.Is_Open (File) then SIO.Close (File); end if;
      Free_Stream (Encoded);
      Free_Bytes (Bytes);
   end Release_Input;
begin
   if R.Lifecycle.Closed then
      Status := Background_Closed;
      return;
   elsif Opacity_Percent > 100 then
      Status := Background_Decode_Failed;
      return;
   elsif Path = "" then
      Clear_Current;
      R.View_State.Background_Opacity := Float (Opacity_Percent) / 100.0;
      Status := Background_Cleared;
      return;
   end if;

   SIO.Open (File, SIO.In_File, Path);
   declare
      Length : constant SIO.Count := SIO.Size (File);
      Limit : constant Natural := R.Graphics_State.Policy.Limits.Per_Image_Bytes;
   begin
      if Length = 0 then
         SIO.Close (File);
         Status := Background_Decode_Failed;
         return;
      elsif Length > SIO.Count (Limit) then
         SIO.Close (File);
         Status := Background_Too_Large;
         return;
      end if;
      Encoded := new Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Length));
      SIO.Read (File, Encoded.all, Last);
      SIO.Close (File);
      if Last /= Encoded'Last then
         Release_Input;
         Status := Background_Decode_Failed;
         return;
      end if;
      Bytes := new Terminal.Common.Bytes.Byte_Array (1 .. Natural (Length));
      for I in Bytes'Range loop
         Bytes (I) := Terminal.Common.Bytes.Byte
           (Encoded (Ada.Streams.Stream_Element_Offset (I)));
      end loop;
   end;
   Free_Stream (Encoded);

   Terminal.App.Image_Media.Decode
     (Bytes.all,
      Bytes'Length,
      Terminal.App.Image_Media.Decode_Byte_Limit
        (R.Graphics_State.Policy.Limits.Per_Image_Bytes),
      R.Graphics_State.Policy.Limits.Pixel_Dimension,
      Image,
      Decode_Status,
      Maximum_Frames => R.Graphics_State.Policy.Limits.Animation_Frames);
   Free_Bytes (Bytes);
   if Decode_Status /= Terminal.App.Image_Media.Decode_Ok
     or else Terminal.App.Image_Media.Frame_Count (Image) = 0
   then
      Status :=
        (if Decode_Status = Terminal.App.Image_Media.Decode_Too_Large
         then Background_Too_Large
         elsif Decode_Status = Terminal.App.Image_Media.Decode_Allocation_Failed
         then Background_Allocation_Failed
         else Background_Decode_Failed);
      return;
   end if;

   Terminal.App.Owned_Image_Data.Allocate
     (Image_Owner, Terminal.App.Image_Media.Frame_Bytes (Image));
   declare
      procedure Copy_First_Frame
        (Target : in out Terminal.Common.Bytes.Byte_Array) is
      begin
         Terminal.App.Image_Media.Copy_Frame (Image, 1, Target);
      end Copy_First_Frame;
   begin
      Terminal.App.Owned_Image_Data.Modify
        (Image_Owner, Copy_First_Frame'Access);
   end;
   Take_Image_Object
     (R              => R,
      Stream_ID      => Background_Stream,
      ID             => Background_ID,
      Image_Number   => 0,
      Usage_Hint     => 0,
      Protocol       => RM.Image_Kitty,
      Raw_Format     => 32,
      Pixel_Width    => Terminal.App.Image_Media.Pixel_Width (Image),
      Pixel_Height   => Terminal.App.Image_Media.Pixel_Height (Image),
      Decoded_Length => Terminal.App.Image_Media.Frame_Bytes (Image),
      Decoded_Row_Stride_Bytes =>
        Terminal.App.Image_Media.Pixel_Width (Image) * 4,
      Bytes          => Image_Owner,
      Stored_Object  => Stored);
   if Stored = null then
      Status := Background_Allocation_Failed;
      return;
   end if;
   R.View_State.Background_Object := Stored;
   R.View_State.Background_Opacity := Float (Opacity_Percent) / 100.0;
   Status := Background_Ok;
exception
   when Ada.IO_Exceptions.Name_Error =>
      Release_Input;
      Status := Background_Invalid_Path;
   when Storage_Error =>
      Release_Input;
      Status := Background_Allocation_Failed;
   when others =>
      Release_Input;
      Status := Background_Decode_Failed;
end Set_Background_Image;
