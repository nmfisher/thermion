enum ShadowType {
  PCF, //!< percentage-closer filtered shadows (default)
  VSM, //!< variance shadows
  DPCF, //!< PCF with contact hardening simulation
  PCSS, //!< PCF with soft shadows and contact hardening
}