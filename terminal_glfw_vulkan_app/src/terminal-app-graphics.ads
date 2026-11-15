with Ada.Finalization;
with Terminal.Common.Bytes;
with Terminal.Common.Graphics_Limits;
with Terminal.App.Image_Decode;
with Terminal.App.Graphics_Types;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Render_Model;
with Terminal.Core;

package Terminal.App.Graphics is
   Max_Status_Label_Length : constant := 64;
   Max_Data_Preview_Length : constant :=
     Terminal.App.Render_Model.Max_Image_Decoded_Data_Length;
   Max_Sixel_Pixel_Dimension : constant :=
     Terminal.Common.Graphics_Limits.Max_Pixel_Dimension;

   --  Private Kitty transmit formats: the payload is a JPEG or GIF file,
   --  decoded here as the iTerm2 inline images are. Kitty's own formats are
   --  8, 16, 24, 32, and 100 (PNG); these sit far from them.
   Kitty_JPEG_Format : constant := 1001;
   Kitty_GIF_Format  : constant := 1002;

   subtype Graphics_Protocol is Graphics_Types.Graphics_Protocol;
   Sixel  : constant Graphics_Protocol := Graphics_Types.Sixel;
   Kitty  : constant Graphics_Protocol := Graphics_Types.Kitty;
   ITerm2 : constant Graphics_Protocol := Graphics_Types.ITerm2;
   subtype Sixel_Color is Graphics_Types.Sixel_Color;
   subtype Sixel_Palette_State is Graphics_Types.Sixel_Palette_State;
   function Default_Sixel_Palette return Sixel_Palette_State;

   subtype Protocol_Capability is Graphics_Types.Protocol_Capability;
   subtype Emoji_Capability is Graphics_Types.Emoji_Capability;
   subtype ITerm2_Size_Unit is Graphics_Types.ITerm2_Size_Unit;
   ITerm2_Auto : constant ITerm2_Size_Unit := Graphics_Types.ITerm2_Auto;
   ITerm2_Cells : constant ITerm2_Size_Unit := Graphics_Types.ITerm2_Cells;
   ITerm2_Pixels : constant ITerm2_Size_Unit := Graphics_Types.ITerm2_Pixels;
   ITerm2_Percent : constant ITerm2_Size_Unit := Graphics_Types.ITerm2_Percent;

   subtype Graphics_Header is Graphics_Types.Graphics_Header;

   subtype Data_Preview_Length_Range is Natural range 0 .. Max_Data_Preview_Length;
   subtype Data_Decode_Byte_Limit is
     Positive range 1 .. Max_Data_Preview_Length;

   subtype Data_Decode_Status is Terminal.App.Image_Decode.Status;
   Decode_Not_Attempted : constant Data_Decode_Status :=
     Terminal.App.Image_Decode.Decode_Not_Attempted;
   Decode_Ok : constant Data_Decode_Status :=
     Terminal.App.Image_Decode.Decode_Ok;
   Decode_Invalid_Byte : constant Data_Decode_Status :=
     Terminal.App.Image_Decode.Decode_Invalid_Byte;
   Decode_Trailing_Data : constant Data_Decode_Status :=
     Terminal.App.Image_Decode.Decode_Trailing_Data;
   Decode_Preview_Truncated : constant Data_Decode_Status :=
     Terminal.App.Image_Decode.Decode_Preview_Truncated;
   Decode_Invalid_Data : constant Data_Decode_Status :=
     Terminal.App.Image_Decode.Decode_Invalid_Data;
   Decode_Too_Large : constant Data_Decode_Status :=
     Terminal.App.Image_Decode.Decode_Too_Large;
   Decode_Allocation_Failed : constant Data_Decode_Status :=
     Terminal.App.Image_Decode.Decode_Allocation_Failed;
   Decode_Unsupported_Format : constant Data_Decode_Status :=
     Terminal.App.Image_Decode.Decode_Unsupported_Format;

   type Graphics_Data_Preview is
     new Ada.Finalization.Limited_Controlled with private;

   overriding procedure Finalize (Data : in out Graphics_Data_Preview);
   function Header_Recognized (Data : Graphics_Data_Preview) return Boolean;
   function Has_Data (Data : Graphics_Data_Preview) return Boolean;
   function Encoded_Length (Data : Graphics_Data_Preview) return Natural;
   function Raw_Format (Data : Graphics_Data_Preview) return Natural;
   function Pixel_Width (Data : Graphics_Data_Preview) return Natural;
   function Pixel_Height (Data : Graphics_Data_Preview) return Natural;
   function Decoded_Length
     (Data : Graphics_Data_Preview) return Data_Preview_Length_Range;
   function Decoded_Row_Stride_Bytes
     (Data : Graphics_Data_Preview) return Natural;
   function Decode_Complete (Data : Graphics_Data_Preview) return Boolean;
   function Decode_Status
     (Data : Graphics_Data_Preview) return Data_Decode_Status;
   function Has_Bytes (Data : Graphics_Data_Preview) return Boolean;
   function Byte_At
     (Data : Graphics_Data_Preview;
      Offset : Positive) return Terminal.Common.Bytes.Byte;
   procedure Read_Bytes
     (Data    : Graphics_Data_Preview;
      Process : not null access procedure
        (Bytes : Terminal.Common.Bytes.Byte_Array));
   --  Read_Bytes scopes the borrowed view to the callback. Take_Bytes
   --  requires a successful complete decode. Decoder-owned capacity retained
   --  after a failed attempt remains private and reusable.

   function Metadata_Preview
     (Header_Recognized : Boolean;
      Has_Data          : Boolean;
      Raw_Format        : Natural;
      Pixel_Width       : Natural;
      Pixel_Height      : Natural) return Graphics_Data_Preview;

   procedure Set_Decode_Failure
     (Data   : in out Graphics_Data_Preview;
      Status : Data_Decode_Status);
   procedure Record_External_Decode
     (Data                     : in out Graphics_Data_Preview;
      Encoded_Length           : Natural;
      Raw_Format               : Natural;
      Pixel_Width              : Natural;
      Pixel_Height             : Natural;
      Decoded_Length           : Data_Preview_Length_Range;
      Decoded_Row_Stride_Bytes : Natural;
      Status                   : Data_Decode_Status);
   --  Decoding is a build capability. Rendering is a runtime capability and
   --  therefore remains false unless an initialized backend confirms it.
   function Capability
     (Protocol            : Graphics_Protocol;
      Rendering_Available : Boolean := False) return Protocol_Capability;
   function Color_Emoji
     (Color_Font_Available : Boolean := False) return Emoji_Capability;
   function Name (Protocol : Graphics_Protocol) return String;
   function Name (Protocol : Terminal.Core.Graphics_Protocol_Kind)
                  return String;
   function Capability_Status_Label
     (Protocol            : Graphics_Protocol;
      Rendering_Available : Boolean := False) return String;
   function Header (Event : Terminal.Core.Graphics_Event) return Graphics_Header;
   function Kitty_Result_From_Header
     (Value : Graphics_Header;
      Code  : Terminal.Core.Graphics_Completion_Code :=
        Terminal.Core.Graphics_No_Response)
      return Terminal.Core.Graphics_Completion;
   function Header_Text
     (Protocol : Terminal.Core.Graphics_Protocol_Kind;
      Text     : String) return Graphics_Header;
   function Data_Preview
     (Event : Terminal.Core.Graphics_Event) return Graphics_Data_Preview;
   procedure Data_Preview
     (Event  : Terminal.Core.Graphics_Event;
      Result : in out Graphics_Data_Preview);
   function Data_Preview_Text
     (Protocol : Terminal.Core.Graphics_Protocol_Kind;
      Text     : String) return Graphics_Data_Preview;
   --  This constructor is visible because Graphics_Data_Preview is tagged:
   --  Ada requires primitive functions with a controlling result to be
   --  declared in the visible part. Other codec entry points are grouped in
   --  Terminal.App.Graphics.Media_Decoders and Decoding.
   function JPEG_Data_Preview_Text
     (Text : String; Maximum_Decoded_Bytes : Data_Decode_Byte_Limit;
      Maximum_Pixel_Dimension : Positive) return Graphics_Data_Preview;
   procedure Release (Data : in out Graphics_Data_Preview);
   procedure Adopt_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner);
   procedure Take_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner);
   procedure Move
     (Source : in out Graphics_Data_Preview;
      Target : in out Graphics_Data_Preview);
   function Data_Decode_Status_Suffix
     (Status : Data_Decode_Status) return String;
   function Image_Decode_Status
     (Status : Data_Decode_Status)
      return Terminal.App.Render_Model.Image_Decode_Status;
   function Data_Status_Label
     (Event : Terminal.Core.Graphics_Event) return String;
   function Header_Status_Label
     (Event : Terminal.Core.Graphics_Event) return String;
   function Placeholder_Cols
     (Event : Terminal.Core.Graphics_Event) return Positive;
   function Placeholder_Rows
     (Event : Terminal.Core.Graphics_Event) return Positive;
   function Graphics_Status_Label
     (Diagnostics : Terminal.Core.Diagnostic_Snapshot) return String;
private
   type Data_Storage_Kind is
     (No_Data_Storage,
      Owned_Data_Storage,
      External_Data_Storage,
      Detached_Data_Storage);
   type Graphics_Data_Storage is limited record
      Bytes : Terminal.App.Owned_Image_Data.Owner;
   end record;
   type Graphics_Data_Preview is
     new Ada.Finalization.Limited_Controlled with record
      Storage           : Graphics_Data_Storage;
      Header_Recognized : Boolean := False;
      Has_Data          : Boolean := False;
      Encoded_Length    : Natural := 0;
      Raw_Format        : Natural := 0;
      Pixel_Width       : Natural := 0;
      Pixel_Height      : Natural := 0;
      Decoded_Length    : Data_Preview_Length_Range := 0;
      Decoded_Row_Stride_Bytes : Natural := 0;
      Decode_Complete   : Boolean := False;
      Decode_Status     : Data_Decode_Status := Decode_Not_Attempted;
      Storage_State     : Data_Storage_Kind := No_Data_Storage;
      Captured_RGBA_Rows : Natural := 0;
   end record;

end Terminal.App.Graphics;
