type WordmarkProps = {
  className?: string;
};

/** Colorful “Sun Kidz” wordmark with tagline (landlogo) */
export function BrandWordmark({ className = "" }: WordmarkProps) {
  return (
    <img
      src="/brand/landlogo.png"
      alt="Sun Kidz — Making Childhood a Celebration"
      className={`brand-wordmark ${className}`.trim()}
      width={520}
      height={189}
      decoding="async"
    />
  );
}

type MarkProps = {
  className?: string;
  size?: number;
};

/** Circular sun mark */
export function BrandMark({ className = "", size = 64 }: MarkProps) {
  return (
    <img
      src="/brand/sunkidz-logo.png"
      alt=""
      role="presentation"
      className={`brand-mark ${className}`.trim()}
      width={size}
      height={size}
      decoding="async"
    />
  );
}

/** Hand-lettered multicolour “Sun Kidz” logotype (from the mobile app) */
export function BrandLettering({ className = "" }: WordmarkProps) {
  return (
    <img
      src="/brand/sunkidz-lettering.png"
      alt=""
      role="presentation"
      className={`brand-lettering ${className}`.trim()}
      width={910}
      height={274}
      decoding="async"
    />
  );
}
