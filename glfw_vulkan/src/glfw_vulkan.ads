with Ada.Finalization;
with Interfaces;
with Interfaces.C;

package GLFW_Vulkan is
   type Context is new Ada.Finalization.Limited_Controlled with private;
   type Runtime_Lease is limited private;

   type Init_Status is
     (Ok,
      Already_Initialized,
      GLFW_Init_Failed,
      Vulkan_Not_Supported,
      Runtime_Unavailable);

   procedure Initialize
     (Ctx    : in out Context;
      Status : out Init_Status);

   overriding procedure Finalize (Ctx : in out Context);

   function Is_Initialized (Ctx : Context) return Boolean;
   function Runtime_Transition_Failure_Count return Natural;

private
   procedure Retain_Runtime (Lease : in out Runtime_Lease);
   procedure Release_Runtime (Lease : in out Runtime_Lease);

   type Runtime_Lease is limited record
      Acquired    : Boolean := False;
      Needs_Start : Boolean := False;
      Needs_Stop  : Boolean := False;
      Raw_Started : Boolean := False;
      Raw_Stopped : aliased Interfaces.C.int := 0;
      Generation  : Interfaces.Unsigned_64 := 0;
   end record;

   type Context is new Ada.Finalization.Limited_Controlled with record
      Initialized : Boolean := False;
      Lease       : Runtime_Lease;
   end record;
end GLFW_Vulkan;

