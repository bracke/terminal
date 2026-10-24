with Terminal.Common.Bytes;
with Terminal.App.Image_Store;

package body Terminal.App.Image_Ingestion is
   function Payload_Start
     (Protocol : Payload_Protocol;
      Text     : String) return Natural
   is
      Separator : constant Character :=
        (if Protocol = Kitty then ';' else ':');
   begin
      for I in Text'Range loop
         if Text (I) = Separator then
            return (if I < Text'Last then I + 1 else 0);
         end if;
      end loop;
      return 0;
   end Payload_Start;

   function Copy_Text
     (Text    : String;
      Control : in out Terminal.App.Image_Store.Allocation_Control)
      return Terminal.App.Render_Model.Image_Data_Access
   is
      Result : Terminal.App.Render_Model.Image_Data_Access;
   begin
      if Text'Length = 0 then
         return null;
      end if;

      if not Terminal.App.Image_Store.Allocation_Allowed (Control) then
         return null;
      end if;

      Result := new Terminal.Common.Bytes.Byte_Array (1 .. Text'Length);
      for I in Text'Range loop
         Result (I - Text'First + 1) :=
           Terminal.Common.Bytes.Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   exception
      when Storage_Error =>
         return null;
   end Copy_Text;
end Terminal.App.Image_Ingestion;
