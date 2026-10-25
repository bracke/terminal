with Ada.Finalization;
with Ada.Streams;
with Terminal.Common.Bytes;
with Terminal.App.Image_Decode;
with Terminal.App.Render_Model;
with Zlib;

--  One bounded streaming zlib inflater shared by direct and Base64 transports.
--  The caller feeds compressed bytes and receives the completed allocation only
--  after Finish has verified the stream terminator and length contract.
package Terminal.App.Zlib_Inflation is
   type Decoder is limited private;

   procedure Start
     (State          : in out Decoder;
      Maximum_Length : Natural;
      Exact_Length   : Boolean;
      Status         : out Terminal.App.Image_Decode.Status);

   procedure Push
     (State    : in out Decoder;
      Value    : Terminal.Common.Bytes.Byte;
      Continue : in out Boolean);

   procedure Finish
     (State           : in out Decoder;
      Inflated        : out Terminal.App.Render_Model.Image_Data_Access;
      Inflated_Length : out Natural;
      Status          : out Terminal.App.Image_Decode.Status);

private
   Buffer_Size : constant := 4_096;
   type Decoder is new Ada.Finalization.Limited_Controlled with record
      Filter         : Zlib.Filter_Type;
      Opened         : Boolean := False;
      Ready          : Boolean := False;
      Failed         : Boolean := False;
      Failure_Status : Terminal.App.Image_Decode.Status :=
        Terminal.App.Image_Decode.Decode_Invalid_Byte;
      Maximum_Length : Natural := 0;
      Exact_Length   : Boolean := False;
      Output         : Terminal.App.Render_Model.Image_Data_Access := null;
      Output_Length  : Natural := 0;
      Input          : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Buffer_Size)) := (others => 0);
      Input_Length   : Natural := 0;
   end record;

   overriding procedure Finalize (State : in out Decoder);
end Terminal.App.Zlib_Inflation;
