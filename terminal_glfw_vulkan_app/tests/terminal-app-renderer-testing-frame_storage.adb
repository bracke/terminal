with Ada.Unchecked_Deallocation;
with AUnit.Assertions;
with Terminal.App.Frame_Image_Storage;
with Terminal.App.Graphics;
with Terminal.App.Image_Data;
with Terminal.App.Image_Store;
with Terminal.App.Owned_Image_Data;
with Terminal.App.Renderer.Animations;
with Terminal.Common.Bytes;

package body Terminal.App.Renderer.Testing.Frame_Storage is
   procedure Verify_Frame_Image_Storage_Invariants is
      use AUnit.Assertions;
      use type Terminal.App.Render_Model.Image_Data_View;
      use type Terminal.App.Render_Model.Image_Array_View;
      use type Terminal.App.Render_Model.Image_Decoded_Source_Kind;
      use type Terminal.App.Render_Model.Image_Protocol;
      use type Terminal.App.Image_Store.Image_Object_Access;
      use type Terminal.Common.Bytes.Byte;

      package FIS renames Terminal.App.Frame_Image_Storage;
      package RM renames Terminal.App.Render_Model;

      procedure Free is new Ada.Unchecked_Deallocation
        (Terminal.Common.Bytes.Byte_Array, Terminal.App.Image_Data.Image_Data_Access);

      S : FIS.Storage;
      Success : Boolean;
      Decoded : Terminal.App.Owned_Image_Data.Owner;
      Encoded : Terminal.App.Owned_Image_Data.Owner;
      Preview : Terminal.App.Owned_Image_Data.Owner;
   begin
      Terminal.App.Owned_Image_Data.Allocate (Decoded, 4);
      Terminal.App.Owned_Image_Data.Fill (Decoded, 16#11#);
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
        (Terminal.App.Owned_Image_Data.Is_Empty (Decoded)
         and then Terminal.App.Owned_Image_Data.Is_Empty (Encoded)
         and then Terminal.App.Owned_Image_Data.Is_Empty (Preview),
         "append transfers controlled buffers");
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
         Unowned : FIS.Storage;
         Data : Terminal.App.Image_Data.Image_Data_Access :=
           new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#66#);
         Rejected : Boolean := False;
      begin
         FIS.Ensure_Capacity (Unowned, 1, Success);
         begin
            FIS.Append
              (Unowned,
               (Protocol => RM.Image_Kitty,
                Decoded_Bytes => Terminal.App.Image_Data.Read_Only (Data),
                others => <>));
         exception
            when Program_Error =>
               Rejected := True;
         end;
         Assert (Rejected, "unowned command byte views are rejected");
         Free (Data);
      end;

      declare
         Automatic : FIS.Storage;
         Owned : Terminal.App.Owned_Image_Data.Owner;
         Null_Encoded : Terminal.App.Owned_Image_Data.Owner;
         Null_Preview : Terminal.App.Owned_Image_Data.Owner;
      begin
         Terminal.App.Owned_Image_Data.Allocate (Owned, 8);
         Terminal.App.Owned_Image_Data.Fill (Owned, 16#22#);
         FIS.Ensure_Capacity (Automatic, 1, Success);
         Assert (Success, "automatic storage capacity");
         FIS.Append
           (Automatic,
            (Protocol => RM.Image_ITerm2, others => <>),
            Owned,
            Null_Encoded,
            Null_Preview);
         Assert
           (Terminal.App.Owned_Image_Data.Is_Empty (Owned),
            "append consumes unreferenced transferred data");
      end;

      declare
         Invalid : FIS.Storage;
         Owned_Decoded : Terminal.App.Owned_Image_Data.Owner;
         Null_Encoded  : Terminal.App.Owned_Image_Data.Owner;
         Null_Preview  : Terminal.App.Owned_Image_Data.Owner;
         Rejected      : Boolean := False;
      begin
         Terminal.App.Owned_Image_Data.Allocate (Owned_Decoded, 4);
         Terminal.App.Owned_Image_Data.Fill (Owned_Decoded, 16#33#);
         FIS.Ensure_Capacity (Invalid, 1, Success);
         Assert (Success, "invalid-description storage capacity");
         begin
            FIS.Append
              (Invalid,
               (Protocol            => RM.Image_Kitty,
                Decoded_Source      => RM.Image_Decoded_Source_Buffer,
                Decoded_Bytes       =>
                  Terminal.App.Owned_Image_Data.Unsafe_View (Owned_Decoded),
                Decoded_Byte_Length => 5,
                others              => <>),
               Owned_Decoded,
               Null_Encoded,
               Null_Preview);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected
            and then FIS.Count (Invalid) = 0
            and then not Terminal.App.Owned_Image_Data.Is_Empty
              (Owned_Decoded),
            "inconsistent image lengths are rejected before ownership moves");
      end;

      declare
         package Store renames Terminal.App.Image_Store;
         Images : Store.Store;
         Object : Store.Image_Object_Access;
         Borrowed : FIS.Storage;
         Root : Terminal.App.Owned_Image_Data.Owner;
         Replacement : Terminal.App.Owned_Image_Data.Owner;
         Foreign : Terminal.App.Image_Data.Image_Data_Access :=
           new Terminal.Common.Bytes.Byte_Array'(1 .. 4 => 16#77#);
         Rejected : Boolean := False;
      begin
         Terminal.App.Owned_Image_Data.Allocate (Root, 4);
         Terminal.App.Owned_Image_Data.Fill (Root, 16#44#);
         Terminal.App.Owned_Image_Data.Allocate (Replacement, 4);
         Terminal.App.Owned_Image_Data.Fill (Replacement, 16#55#);
         Store.Create_Object (Object);
         Store.Link_New (Images, Object);
         Store.Install_Root
           (Images,
            Object,
            Stream_ID      => 1,
            ID             => 1,
            Number         => 0,
            Protocol       => RM.Image_Kitty,
            Raw_Format     => 32,
            Pixel_Width    => 1,
            Pixel_Height   => 1,
            Decoded_Length => 4,
            Row_Stride     => 4,
            Usage_Hint     => 0,
            Data           => Root);
         FIS.Ensure_Capacity (Borrowed, 1, Success);
         Assert (Success, "borrow storage capacity");
         begin
            FIS.Append
              (Borrowed,
               (Protocol      => RM.Image_Kitty,
                Decoded_Bytes => Terminal.App.Image_Data.Read_Only (Foreign),
                others        => <>));
         exception
            when Program_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected and then FIS.Count (Borrowed) = 0,
            "frame storage rejects an unowned byte view");
         Rejected := False;
         begin
            FIS.Append_Borrowed_Frame
              (Borrowed,
               (Protocol      => RM.Image_Kitty,
                Decoded_Bytes => Terminal.App.Image_Data.Read_Only (Foreign),
                others        => <>),
               Object,
               1);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected and then FIS.Count (Borrowed) = 0,
            "borrowed-frame append rejects externally supplied byte views");
         Free (Foreign);
         Rejected := False;
         begin
            FIS.Append_Borrowed_Frame
              (Borrowed,
               (Protocol => RM.Image_Kitty, others => <>),
               Object,
               2);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected and then FIS.Count (Borrowed) = 0,
            "missing borrowed frame is rejected without publishing a slot");
         declare
            Probe : Terminal.App.Owned_Image_Data.Owner;
         begin
            Terminal.App.Owned_Image_Data.Allocate (Probe, 4);
            Terminal.App.Owned_Image_Data.Fill (Probe, 16#44#);
            Store.Replace_Root_RGBA (Images, Object, Probe);
            Assert
              (Terminal.App.Owned_Image_Data.Is_Empty (Probe),
               "missing-frame rejection releases its provisional borrow");
         end;
         Rejected := False;
         FIS.Append_Borrowed_Frame
           (Borrowed,
            (Protocol => RM.Image_Kitty, others => <>),
            Object,
            1,
            Use_As_Preview => False);
         Assert
           (FIS.Element (Borrowed, 1).Decoded_Byte_Length = 4
            and then FIS.Element (Borrowed, 1).Decoded_Source =
              RM.Image_Decoded_Source_Buffer
            and then FIS.Element (Borrowed, 1).Decoded_Preview_Bytes = null
            and then FIS.Element (Borrowed, 1).Decoded_Preview_Length = 0
            and then FIS.Element (Borrowed, 1).Encoded_Source_Length = 0,
            "borrowed-frame append derives a consistent command description");
         begin
            Store.Replace_Root_RGBA (Images, Object, Replacement);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         Assert
           (Rejected
            and then not Terminal.App.Owned_Image_Data.Is_Empty (Replacement),
            "pinned frame bytes reject invalidating store mutation");
         FIS.Reset (Borrowed);
         Store.Replace_Root_RGBA (Images, Object, Replacement);
         Assert
           (Terminal.App.Owned_Image_Data.Is_Empty (Replacement),
            "reset releases frame borrow before store mutation");
         FIS.Append_Borrowed_Frame
           (Borrowed,
            (Protocol => RM.Image_Kitty, others => <>),
            Object,
            1,
            Use_As_Preview => False);
         Store.Delete_Object (Images, Object);
         Assert
           (Object = null
            and then FIS.Element (Borrowed, 1).Decoded_Bytes (1) = 16#55#,
            "deletion defers reclamation of pinned frame bytes");
         FIS.Reset (Borrowed);
      end;
   end Verify_Frame_Image_Storage_Invariants;
end Terminal.App.Renderer.Testing.Frame_Storage;
