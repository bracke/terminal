with Ada.Finalization;
with Terminal.Common.Bytes;
with Terminal.Common.Status;
with Terminal.App.Cleanup_Diagnostics;
with Terminal.App.Image_Decode;
with Terminal.App.ITerm2_Controls;
with Terminal.App.Number_Parsing;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Graphics.Preview_Storage;
with Terminal.App.Graphics.Capability_Reporting;
with Terminal.App.Graphics.Media_Decoders;
with Terminal.App.Graphics.Decoding;
with Terminal.App.Graphics.Kitty_Validation;
with Terminal.App.Graphics.Pixel_Layout;
with Terminal.App.Graphics.Sixel_Support;
with Terminal.App.Graphics.Status_Reporting;

package body Terminal.App.Graphics is
   use type Terminal.Core.Graphics_Protocol_Kind;
   use type Terminal.Core.Graphics_ID;
   use type Terminal.App.Render_Model.Image_Data_View;
   use type Terminal.App.Graphics_Types.Graphics_Protocol;
   use type Terminal.App.Graphics_Types.ITerm2_Size_Unit;
   use type Data_Decode_Status;
   use Terminal.App.Graphics.Sixel_Support;

   subtype Image_Data_Holder is Terminal.App.Owned_Image_Data.Owner;


   function Trimmed_Natural (Value : Natural) return String
      renames Terminal.Common.Status.Trimmed_Natural;

   function Preview_Text (Event : Terminal.Core.Graphics_Event) return String is
   begin
      if Event.Preview_Length = 0 then
         return "";
      end if;
      return Event.Preview (1 .. Event.Preview_Length);
   end Preview_Text;

   procedure Release (Data : in out Graphics_Data_Preview) is
   begin
      Preview_Storage.Release (Data);
   end Release;

   function Has_Bytes (Data : Graphics_Data_Preview) return Boolean is
     (Preview_Storage.Has_Bytes (Data));

   function Byte_At
     (Data : Graphics_Data_Preview;
      Offset : Positive) return Terminal.Common.Bytes.Byte is
     (Preview_Storage.Byte_At (Data, Offset));

   procedure Read_Bytes
     (Data    : Graphics_Data_Preview;
      Process : not null access procedure
        (Bytes : Terminal.Common.Bytes.Byte_Array)) is
   begin
      Preview_Storage.Read_Bytes (Data, Process);
   end Read_Bytes;

   function Header_Recognized (Data : Graphics_Data_Preview) return Boolean is
     (Preview_Storage.Header_Recognized (Data));

   function Has_Data (Data : Graphics_Data_Preview) return Boolean is
     (Preview_Storage.Has_Data (Data));

   function Encoded_Length (Data : Graphics_Data_Preview) return Natural is
     (Preview_Storage.Encoded_Length (Data));

   function Raw_Format (Data : Graphics_Data_Preview) return Natural is
     (Preview_Storage.Raw_Format (Data));

   function Pixel_Width (Data : Graphics_Data_Preview) return Natural is
     (Preview_Storage.Pixel_Width (Data));

   function Pixel_Height (Data : Graphics_Data_Preview) return Natural is
     (Preview_Storage.Pixel_Height (Data));

   function Decoded_Length
     (Data : Graphics_Data_Preview) return Data_Preview_Length_Range is
     (Preview_Storage.Decoded_Length (Data));

   function Decoded_Row_Stride_Bytes
     (Data : Graphics_Data_Preview) return Natural is
     (Preview_Storage.Decoded_Row_Stride_Bytes (Data));

   function Decode_Complete (Data : Graphics_Data_Preview) return Boolean is
     (Preview_Storage.Decode_Complete (Data));

   function Decode_Status
     (Data : Graphics_Data_Preview) return Data_Decode_Status is
     (Preview_Storage.Decode_Status (Data));

   function Metadata_Preview
     (Header_Recognized : Boolean;
      Has_Data          : Boolean;
      Raw_Format        : Natural;
      Pixel_Width       : Natural;
      Pixel_Height      : Natural) return Graphics_Data_Preview
   is
   begin
      return Preview_Storage.Metadata_Preview
        (Header_Recognized, Has_Data, Raw_Format, Pixel_Width, Pixel_Height);
   end Metadata_Preview;

   procedure Set_Decode_Failure
     (Data   : in out Graphics_Data_Preview;
      Status : Data_Decode_Status) is
   begin
      Preview_Storage.Set_Decode_Failure (Data, Status);
   end Set_Decode_Failure;

   procedure Record_External_Decode
     (Data                     : in out Graphics_Data_Preview;
      Encoded_Length           : Natural;
      Raw_Format               : Natural;
      Pixel_Width              : Natural;
      Pixel_Height             : Natural;
      Decoded_Length           : Data_Preview_Length_Range;
      Decoded_Row_Stride_Bytes : Natural;
      Status                   : Data_Decode_Status)
   is
   begin
      Preview_Storage.Set_Decode_Metadata
        (Data,
         Decoded_Length > 0,
         Encoded_Length,
         Raw_Format,
         Pixel_Width,
         Pixel_Height,
         Decoded_Length,
         Decoded_Row_Stride_Bytes,
         Status,
         Status = Decode_Ok);
   end Record_External_Decode;

   procedure Adopt_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner)
   is
   begin
      Preview_Storage.Adopt_Bytes (Data, Bytes);
   end Adopt_Bytes;

   procedure Take_Bytes
     (Data  : in out Graphics_Data_Preview;
      Bytes : in out Terminal.App.Owned_Image_Data.Owner)
   is
   begin
      if not Terminal.App.Owned_Image_Data.Is_Empty (Bytes) then
         raise Program_Error with "graphics byte target is already populated";
      end if;
      Preview_Storage.Take_Bytes (Data, Bytes);
   end Take_Bytes;

   overriding procedure Finalize (Data : in out Graphics_Data_Preview) is
   begin
      Release (Data);
   exception
      when E : others =>
         Terminal.App.Cleanup_Diagnostics.Note_Failure
           (Terminal.App.Cleanup_Diagnostics.Media_Decoder,
            E,
            "finalize graphics preview");
   end Finalize;

   procedure Move
     (Source : in out Graphics_Data_Preview;
      Target : in out Graphics_Data_Preview)
   is
   begin
      Preview_Storage.Move (Source, Target);
   end Move;

   function Take
     (Data : in out Graphics_Data_Preview) return Graphics_Data_Preview
   is
   begin
      return Result : Graphics_Data_Preview
      do
         Move (Data, Result);
      end return;
   end Take;

   function Parse_Natural (Text : String) return Natural is
      Value : Natural := 0;
   begin
      if not Terminal.App.Number_Parsing.Try_Natural (Text, Value) then
         return 0;
      end if;
      return Value;
   end Parse_Natural;

   function Valid_Natural_Text (Text : String) return Boolean is
      Value : Natural;
   begin
      return Terminal.App.Number_Parsing.Try_Natural (Text, Value);
   end Valid_Natural_Text;

   function Parse_Graphics_ID
     (Text : String) return Terminal.Core.Graphics_ID
   is
      Value : Terminal.Core.Graphics_ID := 0;
   begin
      if not Terminal.App.Number_Parsing.Try_Graphics_ID (Text, Value) then
         return 0;
      end if;
      return Value;
   end Parse_Graphics_ID;

   function Try_Parse_Integer
     (Text   : String;
      Result : out Integer) return Boolean
   is
   begin
      return Terminal.App.Number_Parsing.Try_Integer (Text, Result);
   end Try_Parse_Integer;

   function Parse_Integer (Text : String) return Integer is
      Result : Integer := 0;
   begin
      if Try_Parse_Integer (Text, Result) then
         return Result;
      else
         return 0;
      end if;
   end Parse_Integer;

   function Clamp_Positive
     (Value    : Natural;
      Fallback : Positive;
      Max      : Positive) return Positive
   is
   begin
      if Value = 0 then
         return Fallback;
      elsif Value > Max then
         return Max;
      else
         return Positive (Value);
      end if;
   end Clamp_Positive;

   function Default_Sixel_Palette return Sixel_Palette_State is
      Palette : Sixel_Palette_State :=
        (others => (R => 16#FF#, G => 16#FF#, B => 16#FF#, A => 16#FF#));
   begin
      Palette (0) := (R => 16#00#, G => 16#00#, B => 16#00#, A => 16#FF#);
      Palette (1) := (R => 16#FF#, G => 16#FF#, B => 16#FF#, A => 16#FF#);
      Palette (2) := (R => 16#FF#, G => 16#00#, B => 16#00#, A => 16#FF#);
      Palette (3) := (R => 16#00#, G => 16#FF#, B => 16#00#, A => 16#FF#);
      Palette (4) := (R => 16#00#, G => 16#00#, B => 16#FF#, A => 16#FF#);
      return Palette;
   end Default_Sixel_Palette;

   function Data_First
     (Protocol : Terminal.Core.Graphics_Protocol_Kind;
      Text  : String) return Natural
   is
      Delimiter : Character := ASCII.NUL;
   begin
      case Protocol is
         when Terminal.Core.Sixel_Graphics =>
            Delimiter := 'q';
         when Terminal.Core.Kitty_Graphics =>
            Delimiter := ';';
         when Terminal.Core.ITerm2_Graphics =>
            Delimiter := ':';
         when Terminal.Core.No_Graphics =>
            return 0;
      end case;

      for I in Text'Range loop
         if Text (I) = Delimiter then
            if I < Text'Last then
               return I + 1;
            else
               return 0;
            end if;
         end if;
      end loop;

      return 0;
   end Data_First;

   function JPEG_Data_Preview_Text
     (Text                    : String;
      Maximum_Decoded_Bytes   : Data_Decode_Byte_Limit;
      Maximum_Pixel_Dimension : Positive) return Graphics_Data_Preview
   is separate;

   function Data_Decode_Status_Suffix
     (Status : Data_Decode_Status) return String
      is (Terminal.App.Image_Decode.Suffix (Status));

   function Image_Decode_Status
     (Status : Data_Decode_Status)
      return Terminal.App.Render_Model.Image_Decode_Status
      is (Status);

   function Capability
     (Protocol            : Graphics_Protocol;
      Rendering_Available : Boolean := False) return Protocol_Capability
   is (Capability_Reporting.Capability (Protocol, Rendering_Available));

   function Color_Emoji
     (Color_Font_Available : Boolean := False) return Emoji_Capability is
     (Capability_Reporting.Color_Emoji (Color_Font_Available));

   function Name (Protocol : Graphics_Protocol) return String is
     (Capability_Reporting.Name (Protocol));

   function Name (Protocol : Terminal.Core.Graphics_Protocol_Kind)
                  return String is
     (Capability_Reporting.Name (Protocol));

   function Capability_Status_Label
     (Protocol            : Graphics_Protocol;
      Rendering_Available : Boolean := False) return String is
     (Capability_Reporting.Status_Label (Protocol, Rendering_Available));

   function Valid_Integer_Text (Text : String) return Boolean is
      Value : Integer;
   begin
      return Try_Parse_Integer (Text, Value);
   end Valid_Integer_Text;

   function Valid_Graphics_ID_Text (Text : String) return Boolean is
      Value : Terminal.Core.Graphics_ID;
   begin
      return Terminal.App.Number_Parsing.Try_Graphics_ID (Text, Value);
   end Valid_Graphics_ID_Text;

   function Parse_Sixel_Header (Text : String) return Graphics_Header
   is separate;
   function Parse_Kitty_Header (Text : String) return Graphics_Header
   is separate;
   function Parse_ITerm2_Header (Text : String) return Graphics_Header
   is separate;

   function Header_Text
     (Protocol : Terminal.Core.Graphics_Protocol_Kind;
      Text     : String) return Graphics_Header
   is separate;

   function Header (Event : Terminal.Core.Graphics_Event) return Graphics_Header is
   begin
      if not Event.Pending then
         return (others => <>);
      end if;
      return Header_Text (Event.Protocol, Preview_Text (Event));
   end Header;

   function Kitty_Result_From_Header
     (Value : Graphics_Header;
      Code  : Terminal.Core.Graphics_Completion_Code :=
        Terminal.Core.Graphics_No_Response)
      return Terminal.Core.Graphics_Completion
   is
      Result : Terminal.Core.Graphics_Completion :=
        (Code => Code, others => <>);
   begin
      if Value.Recognized and then Value.Protocol = Kitty then
         Result.Kitty_Response.Present := True;
         Result.Kitty_Response.Quiet := Natural'Min (Value.Kitty_Quiet, 2);
         Result.Kitty_Response.Respond :=
           not
             (Value.Kitty_Action = 'T'
              and then Value.Kitty_ID = 0
              and then Value.Kitty_Image_Number = 0);
         Result.Kitty_Response.Image_ID := Value.Kitty_ID;
         Result.Kitty_Response.Image_Number := Value.Kitty_Image_Number;
         Result.Kitty_Response.Has_Image_Number := Value.Kitty_Image_Number /= 0;
         Result.Kitty_Response.Placement_ID := Value.Kitty_Placement_ID;
         Result.Kitty_Response.Has_Placement_ID :=
           Value.Kitty_Placement_ID /= 0;
      end if;
      return Result;
   end Kitty_Result_From_Header;

   function Data_Preview_Text
     (Protocol : Terminal.Core.Graphics_Protocol_Kind;
      Text     : String) return Graphics_Data_Preview
   is separate;

   function Data_Preview
     (Event : Terminal.Core.Graphics_Event) return Graphics_Data_Preview
   is
   begin
      if not Event.Pending then
         return
           (Ada.Finalization.Limited_Controlled with others => <>);
      end if;
      return Data_Preview_Text (Event.Protocol, Preview_Text (Event));
   end Data_Preview;

   procedure Data_Preview
     (Event  : Terminal.Core.Graphics_Event;
      Result : in out Graphics_Data_Preview)
   is
      Value : Graphics_Data_Preview := Data_Preview (Event);
   begin
      Move (Value, Result);
   end Data_Preview;

   function Data_Status_Label
     (Event : Terminal.Core.Graphics_Event) return String
   is (Status_Reporting.Data_Label (Event));

   function Header_Status_Label
     (Event : Terminal.Core.Graphics_Event) return String
   is (Status_Reporting.Header_Label (Event));

   function Placeholder_Cols
     (Event : Terminal.Core.Graphics_Event) return Positive
   is
      H : constant Graphics_Header := Header (Event);
   begin
      return H.Placeholder_Cols;
   end Placeholder_Cols;

   function Placeholder_Rows
     (Event : Terminal.Core.Graphics_Event) return Positive
   is
      H : constant Graphics_Header := Header (Event);
   begin
      return H.Placeholder_Rows;
   end Placeholder_Rows;

   function Graphics_Status_Label
     (Diagnostics : Terminal.Core.Diagnostic_Snapshot) return String
   is
      Last : Natural := 0;
      Result : String (1 .. Max_Status_Label_Length);

      procedure Append (Ch : Character) is
      begin
         if Last < Result'Last then
            Last := Last + 1;
            Result (Last) := Ch;
         end if;
      end Append;

      procedure Append_Natural (Value : Natural) is
         Text : constant String := Trimmed_Natural (Value);
      begin
         for Ch of Text loop
            Append (Ch);
         end loop;
      end Append_Natural;

      procedure Append_String (Text : String) is
      begin
         for Ch of Text loop
            Append (Ch);
         end loop;
      end Append_String;
   begin
      if Diagnostics.Graphics_Commands_Received = 0
        or else Diagnostics.Last_Graphics_Protocol = Terminal.Core.No_Graphics
      then
         return "";
      end if;

      Append_String ("Received ");
      case Diagnostics.Last_Graphics_Protocol is
         when Terminal.Core.No_Graphics =>
            null;
         when Terminal.Core.Sixel_Graphics =>
            Append_String ("sixel graphics");
         when Terminal.Core.Kitty_Graphics =>
            Append_String ("kitty graphics");
         when Terminal.Core.ITerm2_Graphics =>
            Append_String ("iTerm2 image");
      end case;
      Append_String (" payload");
      if Diagnostics.Last_Graphics_Payload_Length > 0 then
         Append_String (" (");
         Append_Natural (Diagnostics.Last_Graphics_Payload_Length);
         Append_String (" bytes)");
      end if;

      return Result (1 .. Last);
   end Graphics_Status_Label;
end Terminal.App.Graphics;
