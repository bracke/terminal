with Terminal.Common.Status;

package body Terminal.App.Graphics.Status_Reporting is

   function Data_Label
     (Event : Terminal.Core.Graphics_Event) return String
   is
      Data : Graphics_Data_Preview := Data_Preview (Event);

      function Build_Label return String is
         Result : String (1 .. Max_Status_Label_Length) := (others => ' ');
         Last   : Natural := 0;

         procedure Capture_Byte_Label
           (Bytes : Terminal.Common.Bytes.Byte_Array)
         is
            Label : constant String :=
              Terminal.Common.Status.Preview_Bytes_Label
                (Bytes, Data.Decoded_Length);
         begin
            Last := Natural'Min (Label'Length, Result'Length);
            Result (1 .. Last) := Label (Label'First .. Label'First + Last - 1);
         end Capture_Byte_Label;

         function Byte_Label return String is
         begin
            if not Has_Bytes (Data) then
               return "";
            end if;
            Read_Bytes (Data, Capture_Byte_Label'Access);
            return Result (1 .. Last);
         end Byte_Label;

         function Decoded_Prefix return String is
         begin
            case Event.Protocol is
               when Terminal.Core.Sixel_Graphics =>
                  return "sixel raster decoded=";
               when Terminal.Core.Kitty_Graphics =>
                  return "kitty data preview decoded=";
               when Terminal.Core.ITerm2_Graphics =>
                  return "iTerm2 data preview decoded=";
               when Terminal.Core.No_Graphics =>
                  return "";
            end case;
         end Decoded_Prefix;
      begin
         if not Data.Header_Recognized then
            return "";
         elsif not Data.Has_Data then
            return Name (Event.Protocol) & " data preview unavailable";
         end if;

         return Decoded_Prefix
           & Terminal.Common.Status.Trimmed_Natural (Data.Decoded_Length)
           & "/" & Terminal.Common.Status.Trimmed_Natural (Data.Encoded_Length)
           & Byte_Label
           & (if Data.Decode_Complete then " decoded" else " partial")
           & Data_Decode_Status_Suffix (Data.Decode_Status);
      end Build_Label;
   begin
      declare
         Label : constant String := Build_Label;
      begin
         Release (Data);
         return Label;
      end;
   exception
      when others =>
         Release (Data);
         raise;
   end Data_Label;

   function Header_Label
     (Event : Terminal.Core.Graphics_Event) return String
   is
      H : constant Graphics_Header := Header (Event);
   begin
      if not H.Recognized then
         return "";
      end if;

      case Event.Protocol is
         when Terminal.Core.Sixel_Graphics =>
            return "sixel header ready; payload="
              & Terminal.Common.Status.Trimmed_Natural (Event.Payload_Length)
              & (if H.Pixel_Width > 0 and then H.Pixel_Height > 0
                 then "; pixels="
                   & Terminal.Common.Status.Trimmed_Natural (H.Pixel_Width)
                   & "x"
                   & Terminal.Common.Status.Trimmed_Natural (H.Pixel_Height)
                 else "");
         when Terminal.Core.Kitty_Graphics =>
            return "kitty header ready; format="
              & Terminal.Common.Status.Trimmed_Natural (H.Kitty_Format)
              & (if H.Pixel_Width > 0 and then H.Pixel_Height > 0
                 then "; pixels="
                   & Terminal.Common.Status.Trimmed_Natural (H.Pixel_Width)
                   & "x"
                   & Terminal.Common.Status.Trimmed_Natural (H.Pixel_Height)
                 else "")
              & (if H.Has_Data then "; data previewed"
                 else "; no data preview");
         when Terminal.Core.ITerm2_Graphics =>
            return "iTerm2 header ready; inline="
              & (if H.ITerm2_Inline then "yes" else "no")
              & "; name bytes="
              & Terminal.Common.Status.Trimmed_Natural (H.ITerm2_Name_Length);
         when Terminal.Core.No_Graphics =>
            return "";
      end case;
   end Header_Label;
end Terminal.App.Graphics.Status_Reporting;
