with AUnit.Assertions;

with Terminal.Common.Bytes;
with Terminal.App.Frame_Image_Storage;
with Terminal.App.Render_Model;

procedure Frame_Image_Storage_Smoke is
   use AUnit.Assertions;
   use type Terminal.App.Render_Model.Image_Array_Access;
   use type Terminal.App.Render_Model.Image_Array_View;
   use type Terminal.App.Render_Model.Image_Data_Access;
   use type Terminal.App.Render_Model.Image_Protocol;

   package FIS renames Terminal.App.Frame_Image_Storage;
   package RM renames Terminal.App.Render_Model;

   S : FIS.Storage;
   Success : Boolean;
   Decoded : RM.Image_Data_Access :=
     new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#11#);
   Encoded : RM.Image_Data_Access := Decoded;
   Preview : RM.Image_Data_Access := Decoded;
begin
   FIS.Ensure_Capacity (S, 2, Success);
   Assert (Success and then FIS.Capacity (S) >= 2, "storage capacity");

   FIS.Append
     (S,
      (Protocol => RM.Image_Kitty,
       Pixel_Width => 1,
       Pixel_Height => 1,
       others => <>),
      Decoded,
      Encoded,
      Preview);
   Assert
     (Decoded = null and then Encoded = null and then Preview = null,
      "append transfers aliased buffers");
   Assert
     (FIS.Count (S) = 1
      and then FIS.Commands (S) /= null
      and then FIS.Element (S, 1).Protocol = RM.Image_Kitty,
      "stored image command");

   FIS.Append (S, (Protocol => RM.Image_Sixel, others => <>));
   Assert (FIS.Count (S) = 2 and then FIS.Is_Full (S), "full storage");
   FIS.Truncate (S, 1);
   Assert
     (FIS.Count (S) = 1 and then not FIS.Is_Full (S),
      "truncate releases the removed owner slot");
   FIS.Reset (S);
   Assert
     (FIS.Count (S) = 0 and then FIS.Capacity (S) >= 2,
      "reset retains reusable capacity");
   FIS.Release (S);
   Assert
     (FIS.Count (S) = 0 and then FIS.Capacity (S) = 0,
      "release drops capacity");

   declare
      Automatic : FIS.Storage;
      Owned : RM.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 8 => 16#22#);
      Null_Encoded : RM.Image_Data_Access := null;
      Null_Preview : RM.Image_Data_Access := null;
   begin
      FIS.Ensure_Capacity (Automatic, 1, Success);
      Assert (Success, "automatic storage capacity");
      FIS.Append
        (Automatic,
         (Protocol => RM.Image_ITerm2, others => <>),
         Owned,
         Null_Encoded,
         Null_Preview);
      Assert (Owned = null, "automatic storage owns appended data");
   end;

   declare
      Aliasing : FIS.Storage;
      Owner : RM.Image_Data_Access :=
        new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#33#);
      Retained_Alias : RM.Image_Data_Access := Owner;
      Null_Encoded : RM.Image_Data_Access := null;
      Null_Preview : RM.Image_Data_Access := null;
      Rejected : Boolean := False;
   begin
      FIS.Ensure_Capacity (Aliasing, 2, Success);
      Assert (Success, "alias test storage capacity");
      FIS.Append
        (Aliasing, (Protocol => RM.Image_Kitty, others => <>),
         Owner, Null_Encoded, Null_Preview);
      begin
         FIS.Append
           (Aliasing, (Protocol => RM.Image_Kitty, others => <>),
            Retained_Alias, Null_Encoded, Null_Preview);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      Assert (Rejected, "cross-command owner alias is rejected");
      --  Aliasing owns the allocation; this non-owning copy must not survive
      --  until scope finalization as an apparent second owner.
      Retained_Alias := null;
   end;
end Frame_Image_Storage_Smoke;
