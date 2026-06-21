/**
 * Professional certifications — real Credly verification links from the live
 * site. Badge images weren't available at audit time, so we render the name as
 * a chip linking to its public Credly page. (See PLAN.md NEEDS INPUT: confirm
 * the complete/corrected badge list + images.)
 */
export interface Certification {
  name: string;
  url: string;
}

export const certifications: Certification[] = [
  {
    name: 'Intuit Bookkeeping',
    url: 'https://www.credly.com/badges/f0095a6c-9282-4b35-b3f1-ef05cb18d9c5/public_url',
  },
  {
    name: 'Media Buying Pro',
    url: 'https://www.credly.com/badges/08925a63-361b-4efe-a6d0-76bb1b4e73ee/public_url',
  },
  {
    name: 'Python for Data Science & AI',
    url: 'https://www.credly.com/badges/bb84c6d5-5e96-43c1-941e-e09d8f1233b1/public_url',
  },
  {
    name: 'Python Project for Data Science',
    url: 'https://www.credly.com/badges/27f6fede-f869-4d0d-b0bc-d38033227700/public_url',
  },
  {
    name: 'Tools for Data Science',
    url: 'https://www.credly.com/badges/0c9da6dd-b44e-4695-9306-8f67208fe2f7/public_url',
  },
  {
    name: 'Data Science Methodology',
    url: 'https://www.credly.com/badges/fb9c41c5-623d-478e-ae4d-ba0072bb16e2/public_url',
  },
  {
    name: 'Data Science Orientation',
    url: 'https://www.credly.com/badges/11eed8e1-455c-44f0-b50b-13c75b3bfc02/public_url',
  },
  {
    name: 'Data Science Fundamentals',
    url: 'https://www.credly.com/badges/f4b1027d-1769-4f07-9707-2b9634c7ce7f/public_url',
  },
];
