export const DYNASTY_AI_FEATURES = {
  coachBasic: "ai.coach.basic",
  coachPro: "ai.coach.pro",
  fitnessBasic: "ai.fitness.basic",
  fitnessPro: "ai.fitness.pro",
  videoAnalysis: "ai.video.analysis",
  tournamentPrep: "ai.tournament.prep",
  clubAnalytics: "ai.club.analytics",
  clubFinance: "ai.club.finance",
  clubMarketing: "ai.club.marketing",
  clubCrm: "ai.club.crm",
  clubForecasting: "ai.club.forecasting",
  clubCopilot: "ai.club.copilot",
  coachBusinessAnalytics: "ai.coach_business.analytics",
  coachBusinessCopilot: "ai.coach_business.copilot",
  coachStudentInsights: "ai.coach_business.student_insights",
  tournamentAnalytics: "ai.tournament.analytics",
  tournamentFairPlay: "ai.tournament.fair_play",
  tournamentScheduler: "ai.tournament.scheduler",
  tournamentPromotion: "ai.tournament.promotion",
  commerceRecommendations: "ai.commerce.recommendations",
  commerceSellerInsights: "ai.commerce.seller_insights",
  commercePromotion: "ai.commerce.promotion",
  enterpriseFull: "ai.enterprise.full",
} as const;

export type DynastyAiFeature =
  (typeof DYNASTY_AI_FEATURES)[keyof typeof DYNASTY_AI_FEATURES];

export function hasEntitlement(
  entitlements: Array<{ feature_key?: string | null }>,
  feature: DynastyAiFeature
): boolean {
  return entitlements.some((item) => item.feature_key === feature);
}
