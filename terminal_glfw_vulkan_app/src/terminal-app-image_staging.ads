with Interfaces;
with Terminal.App.Render_Model;
with Terminal.Common.Bytes;

package Terminal.App.Image_Staging is
   type Decode_Status is (Decode_Ok, Invalid_Source, Allocation_Failed);

   procedure Decode_Encoded_Rows
     (Source : Terminal.App.Render_Model.Image_Command;
      Write  : not null access procedure
        (Y        : Natural;
         Row      : Terminal.Common.Bytes.Byte_Array;
         Continue : in out Boolean);
      Status : out Decode_Status);

   --  Decode an encoded render command directly into an RGBA staging sink.
   --  The sink is renderer-independent so Vulkan mapping stays in the backend.
   procedure Decode_Encoded_RGBA
     (Source        : Terminal.App.Render_Model.Image_Command;
      Maximum_Bytes : Positive;
      Write         : not null access procedure
        (Index    : Positive;
         Value    : Interfaces.Unsigned_8;
         Continue : in out Boolean);
      Status        : out Decode_Status);
end Terminal.App.Image_Staging;
